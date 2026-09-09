package render.facility;

import three.Three;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Wall;
import render.world.ContactMaskOpts;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the three pieces of fake ambient occlusion the compound's interior gets, and they are fake for the
// same reason and different SHAPES for a reason of their own.
//
// `masonry` is the floor crease, and it emits no geometry at all — it hands rectangles to
// render.world.ContactMask, which blurs them into a field the floor materials sample. THE QUAD
// VERSION WAS BUILT FIRST AND SHIPPED BROKEN — one gradient quad per wall face, the shape
// render.sewer.SewerDetail and render.world.roofs.RoofShadows both use — and it failed on a fact
// this file's own `slab` call makes obvious in hindsight: a sewer wall face IS the cell boundary, so
// its strips tile, while a facility wall is a SLAB that insets by (CELL - thick)/2 wherever the wall
// line does not carry. Counting how many strips covered each point along one straight run measured
// `111...1111211132` — a GAP at every inset, a DOUBLE or TRIPLE at every notch, and since a quad's
// alpha is uniform along its run, every one of those steps was a hard edge. Reported from the game
// as missing corners and lines beside doors; the band was in fact discontinuous everywhere.
//
// `corners` is the vertical line where two wall faces meet, and it is QUADS, which is not a
// contradiction of the above. A field cannot do it at all: ContactMask is top-down, so every
// fragment of a 6-unit wall face samples the same xz and the whole column would darken flat. And the
// tiling failure that killed the floor strips cannot happen here, because a corner is a POINT
// feature and not a RUN — each strip stands on one face of one notch, meets nothing, and has nothing
// to fail to meet.
//
// `halos` is the shadow a thing STANDING against a wall lays on it, and it is a quad for exactly the
// corner's reason. The floor already knows: every builder that stands something indoors hands its
// footprint to ContactMask.prop and the field darkens the tile under it. The wall knew nothing —
// measured on a shelving unit, the floor at its foot reads 67.6 against 79.1 of open floor while the
// masonry beside it reads 63.93 against the same run's 63.95 a few units along. 11.5/255 on one
// surface and 0.02 on the other, so every fitting and every piece of lab kit met its wall on a hard
// line. And the field cannot reach it: ContactMask is top-down and a wall face is vertical. A
// standing thing is a POINT — one known cuboid on one known plane, meeting nothing — so it is one
// quad, and the whole compound's worth of them merge into one mesh and one draw call.
//
// A RUN IS A POINT ONCE YOU MERGE IT, which is what took the corridor casework the long way round.
// The fittings (render.facility.FacilityDeco) and the lab kit (FacilityKit) went in first because
// each is one object on one cell with the hand of its wall already computed; FacilityTables calls its
// cabinet `unit` once per cell inside a run, so a quad each would OVERLAP along the wall and two of
// these at 0.5 compound to 0.75 — the bug CORNER_EPS below exists for. Its `cabinets` pass hands over
// one halo per claimed run instead, and a merged run is then a point like any other. `len` on the
// opts is what a merged one carries, and 1 is a single object.
//
// THE BENCHES CAME THROUGH HERE AND WENT BACK OUT AGAIN. A bench sits on its CELLS and FacilityGeom
// .slab insets a wall's room face a whole unit into the wall cell, so it never touches the masonry —
// 0.8 at worktop height, 25 px at the game camera. That is a stain on a wall and not a contact
// shadow, and moving the block onto the wall to earn one was built and reverted.
//
// `pool` is the SAME QUAD LAID FLAT, under a box on a shelf plate, and it is here rather than a
// second family because it shares the mesh, the ramp and the weight — the wall gets the shadow of a
// thing standing against it, a shelf gets the shadow of a thing standing on it, and the compound's
// FLOOR field cannot reach either. See `pooled` for the one thing that differs: a plate is small, so
// the quad is shrunk to stay on it.
class FacilityDetail
{
  // the four cell-edge directions, in render.facility.FacilityGeom's own numbering:
  // 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // what `stand` has collected since the last drain. a list rather than a walk of the model for the
  // reason ContactMask.propRects is one: a thing's position is not known until its own builder has
  // run, and re-deriving it here would be re-deriving FacilityDeco's slab clamp backwards
  static var standing:Array<FacilityHaloOpts> = [];

  // and what `pool` has collected, drained by the same call and into the same buffer
  static var lying:Array<FacilityPoolOpts> = [];

  // and what `deck` has collected. same drain, same opts, but its OWN buffer and its own mesh: the
  // ramp is a circle where the other two take a rounded box, and a ramp is an alphaMap, an alphaMap
  // is a material and a material is a draw call. see `halos`
  static var decks:Array<FacilityPoolOpts> = [];
// every rectangle of masonry in the compound, as the SOLID boxes and the HOLES punched back out of
// them. ContactMask paints them in that order.
//
// two subtleties, both of them the reason this returns rects rather than a per-cell predicate:
//   A WALL CELL IS THE UNION OF ITS RUNS, NEVER ITS BOUNDING BOX. `slab` is the box, and at a corner
//     or a T it is strictly bigger than the masonry — the difference is exactly `notches`, so the
//     boxes go in as solid and the notches come back out as holes. Erasing them is also what puts
//     the blur round an inside corner, which is where the quad version needed a radial it never got.
//   A DOORWAY HOLDS NO MASONRY AT FLOOR LEVEL. `carries` counts a door cell so the wall line reads
//     as continuous through it — right for the shell, which has a lintel to emit up at DOOR_H, and
//     wrong down here. Skipping it is the whole of the doorway behaviour: no masonry, no darkening,
//     and the band fades out into the opening over the blur width with nothing special written for it
  public static function masonry(m:Facility):{ solid:Array<ContactRect>, holes:Array<ContactRect> }
    {
      var solid:Array<ContactRect> = [];
      var holes:Array<ContactRect> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!FacilityModel.isWall(m, col, row) ||
                FacilityModel.isDoor(m, col, row))
              continue;
            solid.push(FacilityGeom.slab(m, col, row));
            for (n in FacilityGeom.notches(m, col, row))
              holes.push(n);
          }
      return {
        solid: solid,
        holes: holes,
      };
    }

// a dark strip up each face of every reentrant corner, all of them in ONE merged mesh.
//
// THE CORNERS ARE ALREADY ENUMERATED and this walks the same list render.facility.FacilityGrime
// does, under the same guards. A reentrant corner IS a notch: a wall cell whose line carries both
// ways is an L, `FacilityGeom.notches` punches the square out of its angle, and the two sides of
// that square are the masonry the room's own corner is made of. Deriving it any other way would be
// re-deriving that.
//
// MERGED and not instanced, which is where this parts company with the tunnels' port. Down there the
// corner strips ride the floor strips' own InstancedMesh for free; up here the floor strips do not
// exist — a field replaced them — so there is no batch to ride and the choice is free. One merged
// mesh is one draw call for the whole compound however many corners it has, where an InstancedMesh
// would be the same call plus a per-frame cull it does not need on static geometry.
  public static function corners(scene:Scene, m:Facility):Void
    {
      var b = MeshBufTools.make();
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            // the grime band's own gate, and for the same three reasons: a WINDOW cell's face is cut
            // into a sill run and a head run, a SHUTTER is the hangar's roll-up door, and the hangar
            // is a working shed rather than a finished interior
            if (!FacilityModel.isWall(m, col, row) ||
                m.wall[row][col] != Wall.SOLID ||
                m.structures[m.owner[row][col]].hangar)
              continue;
            for (nt in FacilityGeom.notches(m, col, row))
              {
                if (!FacilityModel.isIndoor(m, nt.col, nt.row))
                  continue;
                // the two planes the notch leaves facing the room, and the point they meet at —
                // which is the corner both strips are opaque at. same pair FacilityGeom's `butt`
                // emits as geometry and FacilityGrime bands
                var cx = (nt.dx == 3 ? nt.x0 : nt.x1);
                var cz = (nt.dz == 1 ? nt.z0 : nt.z1);
                // EACH STRIP STARTS CORNER_EPS OUT FROM THE CORNER, by the same gap it stands off
                // its own wall by, so the two MEET IN PLAN instead of crossing. Run to the corner
                // itself and each one's fully-opaque edge overhangs the other's plane by that gap —
                // and since both are transparent with depthWrite off, the overhanging sliver blends
                // straight through its twin and lays a hard 0.75 line down the corner. Shipped that
                // way once and reported from the game as exactly that
                var e = FacilityStyle.CORNER_EPS;
                post(b, nt.dx, {
                  x0: cx,
                  x1: cx,
                  z0: nt.z0 + (nt.dz == 1 ? e : 0),
                  z1: nt.z1 - (nt.dz == 1 ? 0 : e),
                }, cx, cz);
                post(b, nt.dz, {
                  x0: nt.x0 + (nt.dx == 3 ? e : 0),
                  x1: nt.x1 - (nt.dx == 3 ? 0 : e),
                  z0: cz,
                  z1: cz,
                }, cx, cz);
              }
          }
      add(scene, b, Textures.makeShadowGradient(), FacilityStyle.CORNER_ALPHA);
    }

// collect one wall-hugging thing's silhouette. called by the builders as they place, exactly as
// render.world.ContactMask.prop is and beside it; nothing is drawn until `halos`
  public static function stand(o:FacilityHaloOpts):Void
    standing.push(o);

// collect one thing standing on a surface that is NOT the floor — a box on a shelf plate. same
// collector, same drain, same mesh; the quad is laid flat instead of stood up
  public static function pool(o:FacilityPoolOpts):Void
    lying.push(o);

// collect one thing standing on a laboratory WORKTOP — same opts, same drain, its own mesh because
// its ramp is ROUND. a bench decoration is a flask, a retort stand or a microscope on a bench, and
// the square-cornered field the other two share reads as a mat under one
  public static function deck(o:FacilityPoolOpts):Void
    decks.push(o);

// every collected silhouette as ONE mesh, and the list CLEARED.
//
// the clear is load-bearing and not tidiness: render.facility.FacilityWarm runs FacilityDeco.build
// over FacilityModel.demo(), so a drain that did not empty the list would carry the warm scene's
// three fittings into the first real compound as quads floating at demo-model coordinates. Calling
// this from the warm pass is therefore not optional either — and it warms the program for free.
//
// CALL IT AFTER THE LAST BUILDER THAT STANDS SOMETHING AGAINST A WALL, which is FacilityKit
  public static function halos(scene:Scene, m:Facility):Void
    {
      var b = MeshBufTools.make();
      for (o in standing)
        halo(b, m, o);
      standing = [];
      for (o in lying)
        pooled(b, o);
      lying = [];
      add(scene, b, Textures.makeRectGlowGradient(0, FacilityStyle.HALO_CORE / 2,
        FacilityStyle.HALO_FADE), FacilityStyle.HALO_ALPHA);
      // and the worktop pools, which are the same quad through the same emitter and still cost a
      // SECOND mesh: `add` is parameterised on the ramp and the weight, and this family differs in
      // both. Passing HALO_CORE / 2 as the corner radius AS WELL as the half-extent collapses the
      // rounded-box SDF to a CIRCLE — render.facility.FacilityDeco.lamps' own reading of that
      // generator, and the reason nothing new had to be drawn for it.
      //
      // drained HERE and not from a call of its own, which is the load-bearing part: FacilityWarm
      // runs the builders over FacilityModel.demo() and `halos` is what CLEARS the collectors, so a
      // list drained anywhere else would carry demo-model quads into the first real compound
      var d = MeshBufTools.make();
      for (o in decks)
        pooled(d, o);
      decks = [];
      add(scene, d, Textures.makeRectGlowGradient(FacilityStyle.HALO_CORE / 2,
        FacilityStyle.HALO_CORE / 2, FacilityStyle.HALO_FADE), FacilityStyle.TABLE_POOL_ALPHA);
    }

// how far a quad is grown past its object on one axis, world units.
//
// THE ART FIXES THE RATIO. The rounded-box field is opaque over the middle HALO_CORE of itself and
// fades out over HALO_FADE beyond, so growing an extent to extent / HALO_CORE lands the opaque part
// exactly on the object and the falloff exactly outside it — nothing here picks a reach. What the
// CAP is for is the one case that breaks: the reach is a FRACTION of the object, which is right for
// a bookcase and absurd for a 16-unit casework run. Past the cap the object's own edge maps outside
// the opaque core, so the halo thins along the run rather than ending on a line — see
// FacilityStyle.HALO_GROW_MAX
  static inline function grow(extent:Float):Float
    {
      return Math.min(extent / 2 * (1 / FacilityStyle.HALO_CORE - 1), FacilityStyle.HALO_GROW_MAX);
    }

// one silhouette, on the room-facing plane of the masonry behind it.
//
// CLAMPED ALONG THE WALL and not up it. FacilityGeom.slab insets a face by a unit wherever the wall
// line stops there, so a quad grown past its object's ends can hang off the end of the masonry and
// draw a gradient on open air; the vertical overhang has nowhere to go wrong, and the part below the
// floor is hidden by the floor itself. `u` is taken off the UNCLAMPED span, so a clamp CUTS the
// falloff rather than squeezing it — the stretch this repo does not do.
//
// THE CLAMP IS THE WHOLE RUN'S MASONRY, not the first cell's. `slab` is per cell and a cell is 4
// units, so clamping a 4-cell casework run to it would cut the run to a quarter of itself — the two
// END slabs bound it instead, and for the single-cell case they are the same slab
  static function halo(b:MeshBuf, m:Facility, o:FacilityHaloOpts):Void
    {
      var sc = (o.dir < 2 ? o.len - 1 : 0);
      var sr = (o.dir < 2 ? 0 : o.len - 1);
      var s = FacilityGeom.slab(m, o.col + DC[o.dir], o.row + DR[o.dir]);
      var t = FacilityGeom.slab(m, o.col + sc + DC[o.dir], o.row + sr + DR[o.dir]);
      var p = FacilityGeom.plane(s, o.dir ^ 1, FacilityStyle.HALO_EPS);
      var ga = grow(o.a1 - o.a0);
      var gy = grow(o.h);
      var qa0 = o.a0 - ga;
      var qa1 = o.a1 + ga;
      var qy0 = o.y - gy;
      var qy1 = o.y + o.h + gy;
      var ca0 = Math.max(qa0, Math.min(o.dir < 2 ? s.x0 : s.z0, o.dir < 2 ? t.x0 : t.z0));
      var ca1 = Math.min(qa1, Math.max(o.dir < 2 ? s.x1 : s.z1, o.dir < 2 ? t.x1 : t.z1));
      if (ca1 - ca0 < 0.01)
        return;
      // the collapsed axis comes from the plane and the running one from the clamp, which of the two
      // being which is what `dir` says
      var e = FacilityGeom.ends(
        (o.dir < 2 ? ca0 : p.x0), (o.dir < 2 ? ca1 : p.x1),
        (o.dir < 2 ? p.z0 : ca0), (o.dir < 2 ? p.z1 : ca1), o.dir ^ 1);
      // and WHICH end of the wound quad is which is measured off the world coordinate rather than
      // cased per direction, the same call `post` above makes and for the same reason: `ends` winds
      // a face differently per dir, and hand-casing it would be re-deriving that table backwards
      var ua = ((o.dir < 2 ? e[0] : e[1]) - qa0) / (qa1 - qa0);
      var ub = ((o.dir < 2 ? e[2] : e[3]) - qa0) / (qa1 - qa0);
      MeshBufTools.quad(b,
        [e[0], qy0, e[1]], [e[2], qy0, e[3]], [e[2], qy1, e[3]], [e[0], qy1, e[1]],
        [ua, 0, ub, 0, ub, 1, ua, 1]);
    }

// one TURNED horizontal quad, on the plate the thing stands on.
//
// the wall halo laid flat, and it is here rather than on the shelf's own surface for the reason the
// wall one is not a field: a box's footprint is a patch INSIDE one plate quad, and a vertex channel
// cannot paint a patch inside a quad — it can only ramp between its corners. Subdividing the plate
// to hold one would cost more geometry than the quad does, and the plate is shared with the rack's
// sides in B_SHELF_TOP anyway.
//
// TURNED WITH ITS BOX: the quad is built in the box's own frame and rotated out of it, so a box that
// was set down askew has a shadow that is askew with it. The plate is axis-aligned and the quad is
// not, which is what the clamp below has to live with — it measures the room on the box's
// AXIS-ALIGNED extent and then spends it on a LOCAL margin, which is conservative by the corner's
// own swing and nothing worse, at DECO_BOX_YAW's 0.25 rad.
//
// CLAMPED PER SIDE AND CUT, NEVER SQUEEZED, which is the wall halo's own rule and here it is what
// makes the thing work at all. The plate rarely has the whole reach: a box fitted to the full depth
// FacilityDeco.boxes allows leaves 0.17 of a 1.67-deep shelf, and one pushed against the end of a
// 2.6 run leaves nothing at all on that side. Shrinking the whole quad by its tightest side (built
// that way first) drops it to nothing and 3 of 12 boxes came out with NO shadow, because `boxes`
// fits its big ones by an equality and their room is exactly zero. Each side takes the room it
// actually has instead; the art stays centred on the BOX and not on the quad, and a clamped side's
// uv is cut off the IDEAL reach — so the falloff stops where the plate does and nowhere else
  static function pooled(b:MeshBuf, o:FacilityPoolOpts):Void
    {
      var c = Math.cos(o.yaw), s = Math.sin(o.yaw);
      var a = Math.abs(s);
      var ax = o.hw * c + o.hd * a;
      var az = o.hw * a + o.hd * c;
      var rw = o.hw * FacilityStyle.POOL_GROW;
      var rd = o.hd * FacilityStyle.POOL_GROW;
      var mw0 = Math.min(rw, Math.max(0, o.cx - ax - o.plate.x0));
      var mw1 = Math.min(rw, Math.max(0, o.plate.x1 - o.cx - ax));
      var md0 = Math.min(rd, Math.max(0, o.cz - az - o.plate.z0));
      var md1 = Math.min(rd, Math.max(0, o.plate.z1 - o.cz - az));
      var lx = [-(o.hw + mw0), o.hw + mw1];
      var lz = [-(o.hd + md0), o.hd + md1];
      var u = [0.5 + 0.5 * lx[0] / (o.hw + rw), 0.5 + 0.5 * lx[1] / (o.hw + rw)];
      var v = [0.5 + 0.5 * lz[0] / (o.hd + rd), 0.5 + 0.5 * lz[1] / (o.hd + rd)];
      // wound so the face looks UP: this is the only quad here that is not vertical, and FrontSide on
      // the shared material would cull a back-facing one to nothing
      var y = o.y + FacilityStyle.POOL_EPS;
      MeshBufTools.quad(b,
        [o.cx + lx[0] * c - lz[1] * s, y, o.cz + lx[0] * s + lz[1] * c],
        [o.cx + lx[1] * c - lz[1] * s, y, o.cz + lx[1] * s + lz[1] * c],
        [o.cx + lx[1] * c - lz[0] * s, y, o.cz + lx[1] * s + lz[0] * c],
        [o.cx + lx[0] * c - lz[0] * s, y, o.cz + lx[0] * s + lz[0] * c],
        [u[0], v[1], u[1], v[1], u[1], v[0], u[0], v[0]]);
    }

// one strip: the whole height of one notch face, opaque where that face meets its perpendicular twin
// and fading to nothing over the notch's own length.
//
// THE GRADIENT RUNS ALONG THE FACE, NOT UP IT, which is the whole of the uv here. Textures
// .makeShadowGradient is a 4x64 vertical ramp, opaque at v = 0, and every other user hangs it the
// way it was drawn; this one turns it on its side. So `u` is a constant — the ramp is four texels
// wide and carries no shape across them — and `v` is 0 at the corner and 1 at the far end.
//
// WHICH end is the corner is measured rather than cased. `ends` winds a face differently per `dir`
// so that the front face looks the right way, and hand-casing which of its two returns is the near
// one would be re-deriving that table backwards; taking the nearer of the two to the corner point
// cannot get it wrong and does not care if `ends` is ever retuned
  static function post(b:MeshBuf, dir:Int, s:FacilityGeom.Rect, cx:Float, cz:Float):Void
    {
      var p = FacilityGeom.plane(s, dir, FacilityStyle.CORNER_EPS);
      var e = FacilityGeom.ends(p.x0, p.x1, p.z0, p.z1, dir);
      var da = (e[0] - cx) * (e[0] - cx) + (e[1] - cz) * (e[1] - cz);
      var db = (e[2] - cx) * (e[2] - cx) + (e[3] - cz) * (e[3] - cz);
      var va = (da <= db ? 0.0 : 1.0);
      var vb = 1.0 - va;
      var h = FacilityStyle.WALL_H;
      MeshBufTools.quad(b, [e[0], 0, e[1]], [e[2], 0, e[3]], [e[2], h, e[3]], [e[0], h, e[1]],
        [0.5, va, 0.5, vb, 0.5, vb, 0.5, va]);
    }

// one buffer of dark quads as ONE mesh. shared by the corner strips and the standing halos, which
// differ in nothing but their ramp and their weight — two calls and two programs, because an
// alphaMap is a material and a material is a draw call.
//
// BASIC and not Lambert, unlike the grime band beside it: this is not a surface taking the room's
// light, it is the absence of light, and a lit black quad would brighten with the wall it is meant
// to be darkening. It is the tunnels' own choice for the same quads.
//
// FrontSide matters and is worth a draw call: three renders a transparent DoubleSide material as TWO
// single-side passes, measured 36 -> 34 in the habitat. Each quad faces the room it is in and is
// never seen from behind.
//
// `transparent` is set AFTER VisionMask.patch, the order render.facility.FacilityGeom.addPane and
// FacilityGrime both need: the mask reads that flag at patch time to choose its branch, and set
// first it would fade a hidden strip OUT rather than sinking it toward the fog with its wall
  static function add(scene:Scene, b:MeshBuf, ramp:Texture, alpha:Float):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = VisionMask.patch(new MeshBasicMaterial({
        color: 0x000000,
        alphaMap: ramp,
        opacity: alpha,
        depthWrite: false,
        side: THREE.FrontSide,
      }));
      mat.transparent = true;
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
