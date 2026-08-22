package render.actors;

import three.Three;
import render.particles.Sprites;

// what every ribbon pass has in common, whatever kind of strip it is. it exists because the two
// shipped kinds — render.actors.BoltOpts and render.actors.TetherOpts — were written a day apart and
// agreed on FOURTEEN of their fifteen-odd fields, comments and all. they extend this and add only
// what is genuinely theirs.
//
// every point here is already in WORLD space, and an emitter is called TWICE down the same path (a
// wide soft halo, then the hot core over it), so everything describing that path has to be identical
// between the two calls and only `bright`, `wMul` and `edge` may differ
typedef RibbonPass = {
  h:Float,      // the prop's world height — every authored fraction scales by it
  ph:Float,     // per-strip phase. it MUST match between the two passes, or the halo would run down
                // a different path than the core it is meant to sit under
  sx:Float,     // where the strip starts, world X
  sy:Float,     // start, world Y
  sz:Float,     // start, world Z
  ex:Float,     // where it ends, world X
  ey:Float,     // end, world Y
  ez:Float,     // end, world Z
  bright:Float, // this pass's brightness at the centreline, before the row's own `glow`
  wMul:Float,   // this pass's half-width as a multiple of the row's `width`
  edge:Float,   // and its brightness at the OUTER edge as a fraction of the centreline. 1 is a flat
                // bar (what a core pass wants — a bright thread with a hard edge), 0 falls off to
                // nothing, which is the only reason a halo pass reads as a flare and not as a plank
};

// ONE additive world-space ribbon layer: one mesh, one draw call, however many strips are drawn into
// it this frame and by however many callers. a strip is rebuilt from scratch each frame — the shape
// render.particles.SlimeTrail already uses — so nothing is stored per strip and none of it needs a
// spawn or despawn hook.
//
// it was extracted from render.actors.PropFX once a SECOND kind of strip appeared there (the
// preservator's tethers, beside the biomineral's lightning), and the split is drawn where it is for
// two reasons that are not tidiness:
//
//   1. THE ONE-MESH INVARIANT BECOMES STRUCTURAL. Sharing these three arrays is the entire reason a
//      level's every bolt and every cord costs one call rather than one each. As a convention between
//      two functions in one file that was a thing to remember; as a class it is a thing you cannot
//      get wrong without noticing.
//   2. widthAxis' ZERO-LENGTH GUARD EXISTS ONCE. It was hand-copied verbatim into both emitters, and
//      its failure mode is not cosmetic — one NaN texel goes through the bloom downsample and blacks
//      out the WHOLE frame (see docs/3d-changes.md). A guard like that surviving on copy discipline
//      is a matter of time.
//
// what does NOT live here is the PATH: how a bolt zigzags or a cord bows is the caller's, because it
// is the thing that differs. callers walk their own path and call station() per cross-section and
// quads() to stitch it to the last one
class Ribbon
{
  // the unit width axis, filled by widthAxis() and read straight back out by the caller into its own
  // pass options. public fields rather than a returned structure: this runs per strip per frame and
  // Haxe has no multi-return that does not allocate
  public var nx:Float = 0.0;
  public var ny:Float = 0.0;
  public var nz:Float = 0.0;

  // the resting camera's view direction, ~53 degrees down and looking along -Z. it is used ONLY to
  // face a ribbon and never to place one, which is why a fixed value is honest here: the whole sprite
  // layer already assumes this camera (Sprites.TILT, render.world.ObjModels.PropYaw.FRONTAL), and a
  // bolt is on screen for a quarter of a second
  static inline var VX = 0.0;
  static inline var VY = -0.8;
  static inline var VZ = -0.6;

  var mesh:Mesh;
  var geo:BufferGeometry;
  var pos:Array<Float> = [];
  var col:Array<Float> = [];
  var idx:Array<Int> = [];
  // scratch for whichever strip is being emitted, so the per-frame rebuild allocates no Colors. one
  // shared slot is safe because a caller sets it on entry and emits its stations immediately, so two
  // kinds of strip never interleave over it
  var tint = new Color();

  public function new(group:Group)
    {
      geo = new BufferGeometry();
      mesh = new Mesh(geo, material());
      mesh.renderOrder = Sprites.ORD_ACTOR;
      mesh.visible = false;
      // rebuilt in WORLD coordinates every frame, so three must not frustum-test it against a
      // bounding sphere computed for whatever it happened to hold last frame
      untyped mesh.frustumCulled = false;
      group.add(mesh);
    }

// drop last frame's strips. call once per frame BEFORE any caller emits
  public function begin():Void
    {
      pos.splice(0, pos.length);
      col.splice(0, col.length);
      idx.splice(0, idx.length);
    }

// the tint every station emitted after this call is multiplied by
  public inline function setTint(hex:Int):Void
    {
      tint.setHex(hex);
    }

// how many stations are already in the buffer — a caller's own first vertex index, which it needs to
// stitch its segments with quads()
  public inline function count():Int
    {
      return Std.int(pos.length / 3);
    }

// work out the width axis for a strip running along (dx, dy, dz), leaving it in nx/ny/nz. the
// direction need not be normalized; the axis always is
  public function widthAxis(dx:Float, dy:Float, dz:Float):Void
    {
      nx = dy * VZ - dz * VY;
      ny = dz * VX - dx * VZ;
      nz = dx * VY - dy * VX;
      var l = Math.sqrt(nx * nx + ny * ny + nz * nz);
      // a path aimed exactly along the view has no such axis, and normalizing a zero vector is NaN —
      // not a cosmetic bug: ONE NaN texel goes through the bloom downsample and blacks out the WHOLE
      // frame. any axis will do in that case, because the strip is a point on screen
      if (l < 1e-4)
        {
          nx = 1;
          ny = 0;
          nz = 0;
          return;
        }
      nx /= l;
      ny /= l;
      nz /= l;
    }

// one cross-section: THREE vertices (left edge, centreline, right edge) with their own brightnesses,
// so a pass can carry a real gradient across its width instead of a flat bar. see RibbonPass.edge for
// what the outer ratio buys.
//
// it reads the width axis off the fields above rather than taking it, which is not a shortcut: with
// the axis passed in this was NINE all-Float args carrying three mutually swappable coordinate
// triples — mis-order any two and the ribbon is silently wrong with no compile error. widthAxis is
// called once per strip and both of its passes follow immediately, so the fields are always the
// axis a given station belongs to
  public inline function station(cx:Float, cy:Float, cz:Float, w:Float, c:Float, edge:Float):Void
    {
      vert(cx + nx * w, cy + ny * w, cz + nz * w);
      vert(cx, cy, cz);
      vert(cx - nx * w, cy - ny * w, cz - nz * w);
      colour(c * edge);
      colour(c);
      colour(c * edge);
    }

// stitch one station to the next: two quads, centreline to each edge. `q` is the first vertex index
// of the NEAR station, so this is only ever called while another station follows it. winding is
// irrelevant — the material is DoubleSide and additive blending has no order to get wrong
  public inline function quads(q:Int):Void
    {
      idx.push(q);
      idx.push(q + 3);
      idx.push(q + 1);
      idx.push(q + 1);
      idx.push(q + 3);
      idx.push(q + 4);
      idx.push(q + 1);
      idx.push(q + 4);
      idx.push(q + 2);
      idx.push(q + 2);
      idx.push(q + 4);
      idx.push(q + 5);
    }

// hand this frame's strips to the GPU, or hide the mesh if nobody drew. fresh attributes rather than
// a preallocated buffer with a draw range, which is what render.particles.SlimeTrail does and what
// the counts here justify: six 5-segment bolts is 72 vertices
  public function upload():Void
    {
      if (idx.length == 0)
        {
          mesh.visible = false;
          return;
        }
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geo.setAttribute('color', new Float32BufferAttribute(col, 3));
      geo.setIndex(idx);
      mesh.visible = true;
    }

// one vertex. the strip lives at the prop's own depth, so a bolt's root sits at the crystal's
// mid-depth and the near half of the body occludes it — an arc emerging from inside the mineral
// rather than one pasted over its silhouette
  inline function vert(wx:Float, wy:Float, wz:Float):Void
    {
      pos.push(wx);
      pos.push(wy);
      pos.push(wz);
    }

// one vertex colour. HDR: the tint is LINEAR (Color.setHex decodes sRGB) and `c` already carries the
// row's glow, so a peak lands well over BLOOM_THRESHOLD and the bloom pass is the flare. there is no
// alpha channel on purpose — under additive blending brightness IS the opacity, and a vertex colour
// of 0 adds nothing
  inline function colour(c:Float):Void
    {
      col.push(tint.r * c);
      col.push(tint.g * c);
      col.push(tint.b * c);
    }

// the ribbon material. `vertexColors` is what carries both the fade along a strip and its decay over
// its own life — no map, no per-strip uniform and no opacity write. public and static because the
// boot shader pre-warm needs one of these before any Ribbon exists (see render.View.warmup):
// `vertexColors` is in three's program key, so this is a permutation nothing else in the scene
// compiles, and without warming it the first habitat entry pays a compile hitch.
//
// forceSinglePass: three renders a transparent DoubleSide material as TWO single-side passes, each a
// draw call and each its own program. What the split buys is correct back-to-front ordering between
// the two faces, and ADDITIVE blending is commutative, so there is nothing to order. DoubleSide
// itself stays — a ribbon is a flat shape the player can orbit behind
  public static function material():MeshBasicMaterial
    {
      return new MeshBasicMaterial({
        vertexColors: true,
        transparent: true,
        depthWrite: false,
        side: THREE.DoubleSide,
        forceSinglePass: true,
        blending: THREE.AdditiveBlending,
      });
    }
}
