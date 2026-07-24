package render.particles;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.Textures;
import render.world.WorldCtx;

// the green slime the free (unhosted) parasite leaves as it crawls: a render-only ribbon — one
// triangle strip rebuilt each frame from the parasite's recent path — that follows turns and
// dissolves over the last ~lengthCells tiles, plus a lingering ground puddle dropped where it lands
// from a leap on/off a host. nothing here is persisted (no save fields): the trail is transient
// decoration around the live player, cleared when the parasite enters a host or the view tears down
class SlimeTrail {
  var group:Group;                                       // scene group the ribbon mesh hangs on
  var sprites:Sprites;                                   // shared lit paint surface (draws the landing puddles)
  var mesh:Mesh;                                         // the ribbon strip (one draw call, geometry rebuilt per frame)
  var geo:BufferGeometry;
  var mat:MeshStandardMaterial;
  // committed path points, tail (0) -> head (last). off = stored lateral offset of the centerline (a
  // random-walk = smooth meander), ww = stored width multiplier (per-point jitter for irregular edges)
  var spine:Array<{ x:Float, z:Float, y:Float, off:Float, ww:Float }> = [];
  var puddles:Array<{ x:Float, y:Float, z:Float, age:Float }> = []; // render-only fading landing puddles
  var fade:Float = 1.0;                                   // overall trail alpha; decays after the parasite stops crawling (jump on host) so the trail lingers then fades, not vanishes
  var wasActive:Bool = false;                             // prev-frame active, to start a fresh trail on re-detach (avoid bridging the old pre-jump pos)

  // world-space tunables derived from the cell-based config (computed once)
  var sampleW:Float;     // min move before a new spine point is committed
  var lengthW:Float;     // max path length kept behind the parasite
  var halfW:Float;       // half the ribbon width
  var fadeW:Float;       // tail dissolve band length
  var headFadeW:Float;   // head shaping band length (leading end narrows over this)
  var headMinFrac:Float; // head tip width as a fraction of full (0 = point, 1 = flat cut)
  var waveAmpW:Float;    // max lateral wander of the centerline (world)
  var waveStepW:Float;   // random-walk step per sample (world)
  var stepThresh:Float;  // break the strip where two points differ in height by more than this (curb step)
  var maxSpine:Int;      // spine array cap (memory bound; exact length trim happens per-frame)

  public function new(group:Group, sprites:Sprites)
    {
      this.group = group;
      this.sprites = sprites;
      var S = RenderConfig.SLIME;
      sampleW = S.sampleCells * CityConfig.CELL;
      lengthW = S.lengthCells * CityConfig.CELL;
      halfW = S.widthCells * CityConfig.CELL * 0.5;
      fadeW = S.fadeCells * CityConfig.CELL;
      headFadeW = S.headFadeCells * CityConfig.CELL;
      headMinFrac = S.headMinFrac;
      waveAmpW = S.waveAmpCells * CityConfig.CELL;
      waveStepW = S.waveStepCells * CityConfig.CELL;
      stepThresh = RenderConfig.CURB_H * 0.5;
      maxSpine = Std.int(S.lengthCells / S.sampleCells) + 4;
      // slime-green wet ribbon: chroma-keyed source (grey bg -> alpha) tiled along its length,
      // emissive so the green catches the bloom like the acid/slime splats. built once
      var tex = Textures.loadKeyedTexture(RenderConfig.TEXTURES.slimeTrail, 1.0, 0x5a5d63, 24);
      tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
      geo = new BufferGeometry();
      mat = new MeshStandardMaterial({
        map: tex,
        emissive: RenderConfig.BLOOD.slimeGlow,
        emissiveMap: tex,
        emissiveIntensity: S.glowInt,
        transparent: true,
        opacity: S.baseAlpha,           // overall alpha; the tail-fade vertex alpha multiplies on top
        depthWrite: false,
        depthTest: false,               // draw over the ground always so the raised curb can't occlude it
                                        // (a flat trail at road height would otherwise vanish under a walkway slab)
        vertexColors: true,             // per-vertex RGBA: alpha carries the tail dissolve
        roughness: RenderConfig.BLOOD.wetRough,
        metalness: RenderConfig.BLOOD.wetMetal,
        side: THREE.DoubleSide,
      });
      mesh = new Mesh(geo, mat);
      mesh.renderOrder = Sprites.ORD_DECAL;
      // geometry is rebuilt every frame (stale bounding sphere) + always hugs the player, so skip
      // frustum culling on this one small mesh rather than recompute bounds each rebuild
      untyped mesh.frustumCulled = false;
      mesh.visible = false;
      group.add(mesh);
    }

// drop a lingering slime puddle at a leap's ground contact (called on the parasite's jump on/off a
// host). render-only: fades out over SLIME.puddleLifeMult, not persisted
  public function addPuddle(x:Float, y:Float, z:Float):Void
    {
      puddles.push({
        x: x,
        y: y,
        z: z,
        age: 0.0,
      });
    }

// per-frame: `active` is true only while the free parasite is on the ground; (hx,hz) is its smoothed
// head world pos. samples the path, rebuilds the ribbon strip, and ages/draws the landing puddles
// through the shared paint surface (must sit inside sprites begin/end). each point's ground height is
// sampled at its own world pos (not the parasite's logical cell, which snaps mid-slide over a curb)
  public function update(dtMs:Float, active:Bool, hx:Float, hz:Float):Void
    {
      var step = dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      if (active)
        {
          // fresh trail on becoming a free parasite again (leaving a host): the old spine is stale (it
          // moved as a host), so don't bridge it to the new pos
          if (!wasActive)
            spine = [];
          fade = 1.0;
          sample(hx, hz);
        }
      // stopped crawling (jumped on a host): freeze the trail and fade it out over fadeOutMult, then
      // drop it — do NOT clear instantly
      else if (spine.length > 0)
        {
          fade -= step / RenderConfig.SLIME.fadeOutMult;
          if (fade <= 0.0)
            {
              spine = [];
              fade = 1.0;
            }
        }
      wasActive = active;
      rebuild(active, hx, hz);
      drawPuddles(dtMs);
    }

// release GPU buffers on view teardown
  public function dispose():Void
    {
      group.remove(mesh);
      geo.dispose();
      untyped mat.dispose();
    }

// commit a new spine point once the parasite has crawled sampleW from the last one; bound the array.
// each point stores its own ground height, a random-walked lateral offset (meander) + a width jitter
  function sample(hx:Float, hz:Float):Void
    {
      if (spine.length == 0)
        {
          spine.push({
            x: hx,
            z: hz,
            y: floorYAt(hx, hz),
            off: 0.0,
            ww: widthMul(),
          });
          return;
        }
      var last = spine[spine.length - 1];
      var dx = hx - last.x;
      var dz = hz - last.z;
      var y = floorYAt(hx, hz);
      // force a commit the instant the ground height changes (curb crossing), not only every sampleW —
      // else stepping off a walkway leaves no point on the new level for up to a sample and the strip
      // break has nothing to split against (hangs at the old height). otherwise commit on distance
      var stepCrossed = Math.abs(y - last.y) > stepThresh;
      if (!stepCrossed &&
          dx * dx + dz * dz < sampleW * sampleW)
        return;
      // random-walk the lateral offset toward a gentle meander, clamped to the wander amplitude
      var off = last.off + (Math.random() * 2 - 1) * waveStepW;
      if (off > waveAmpW)
        off = waveAmpW;
      else if (off < -waveAmpW)
        off = -waveAmpW;
      spine.push({
        x: hx,
        z: hz,
        y: y,
        off: off,
        ww: widthMul(),
      });
      // memory bound: drop the oldest; the exact 4-tile length cut is done in rebuild()
      if (spine.length > maxSpine)
        spine.splice(0, spine.length - maxSpine);
    }

// ground height at a world position, via its grid cell (road/alley = 0, walkway/bevel = CURB_H)
  inline function floorYAt(x:Float, z:Float):Float
    {
      var c = CityConfig.worldToCell(x, z);
      return WorldCtx.floorY(c.col, c.row);
    }

// a per-point width multiplier jittered around 1 (irregular, non-parallel ribbon edges)
  inline function widthMul():Float
    {
      return 1.0 + (Math.random() * 2 - 1) * RenderConfig.SLIME.widthJitter;
    }

// rebuild the ribbon triangle strip from the spine + the live head, trimmed to the last lengthW of
// path. width + vertex alpha taper to a point at the tail so it dissolves; the head stays glued to
// the parasite. uv.u runs along the path length (tiles) so the slime texture repeats down it
  function rebuild(active:Bool, hx:Float, hz:Float):Void
    {
      // assemble the render polyline: committed spine (tail->head) + the live head so the tip tracks.
      // the live head inherits the last committed lateral offset (continuity) and full width
      var pts:Array<{ x:Float, z:Float, y:Float, off:Float, ww:Float }> = [];
      for (p in spine)
        pts.push({
          x: p.x,
          z: p.z,
          y: p.y,
          off: p.off,
          ww: p.ww,
        });
      if (active &&
          (pts.length == 0 ||
           sq(pts[pts.length - 1].x - hx, pts[pts.length - 1].z - hz) > 0.0001))
        pts.push({
          x: hx,
          z: hz,
          y: floorYAt(hx, hz),
          off: spine.length > 0 ? spine[spine.length - 1].off : 0.0,
          ww: 1.0,
        });
      // trim the front so only the last lengthW of path remains (tail snaps by whole samples, but the
      // dissolve band keeps it near-invisible there so the step never reads)
      var keepFrom = 0;
      var acc = 0.0;
      var i = pts.length - 1;
      while (i > 0)
        {
          acc += Math.sqrt(sq(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z));
          if (acc > lengthW)
            {
              keepFrom = i;
              break;
            }
          i--;
        }
      if (keepFrom > 0)
        pts = pts.slice(keepFrom);
      if (pts.length < 2)
        {
          mesh.visible = false;
          return;
        }
      // cumulative length from the tail per point (drives uv.u + the dissolve ramp)
      var n = pts.length;
      var cum = [0.0];
      for (k in 1...n)
        cum.push(cum[k - 1] + Math.sqrt(sq(pts[k].x - pts[k - 1].x, pts[k].z - pts[k - 1].z)));
      var cumTotal = cum[n - 1];
      var pos:Array<Float> = [];
      var nrm:Array<Float> = [];
      var uv:Array<Float> = [];
      var col:Array<Float> = [];
      var idx:Array<Int> = [];
      for (k in 0...n)
        {
          // miter tangent: average of the two adjacent segment directions (a plain bevel at corners,
          // no miter-length spike). endpoints use their single segment
          var tx = 0.0;
          var tz = 0.0;
          if (k > 0)
            {
              var ax = pts[k].x - pts[k - 1].x;
              var az = pts[k].z - pts[k - 1].z;
              var al = Math.sqrt(ax * ax + az * az);
              if (al > 0.0001)
                {
                  tx += ax / al;
                  tz += az / al;
                }
            }
          if (k < n - 1)
            {
              var bx = pts[k + 1].x - pts[k].x;
              var bz = pts[k + 1].z - pts[k].z;
              var bl = Math.sqrt(bx * bx + bz * bz);
              if (bl > 0.0001)
                {
                  tx += bx / bl;
                  tz += bz / bl;
                }
            }
          var tl = Math.sqrt(tx * tx + tz * tz);
          if (tl < 0.0001)
            {
              tx = 1.0;
              tz = 0.0;
              tl = 1.0;
            }
          tx /= tl;
          tz /= tl;
          // perpendicular in the ground plane
          var px = -tz;
          var pz = tx;
          // tail: width + alpha ramp 0 (tail point) -> 1 across the dissolve band, full toward the head
          var t = cum[k] / fadeW;
          if (t > 1.0)
            t = 1.0;
          // head: narrow the width to headMinFrac over headFadeW so the leading end is a rounded nub /
          // point, not a flat cut. alpha stays full at the head (freshest slime), only the tail dissolves
          var headT = headFadeW > 0.0 ? (cumTotal - cum[k]) / headFadeW : 1.0;
          if (headT > 1.0)
            headT = 1.0;
          var w = halfW * t * (headMinFrac + (1.0 - headMinFrac) * headT) * pts[k].ww;
          var y = pts[k].y + RenderConfig.SLIME.yOff;
          // meander: shift the whole cross-section sideways by the stored lateral offset
          var cx = pts[k].x + px * pts[k].off;
          var cz = pts[k].z + pz * pts[k].off;
          // two verts per point: left then right
          pos.push(cx + px * w);
          pos.push(y);
          pos.push(cz + pz * w);
          pos.push(cx - px * w);
          pos.push(y);
          pos.push(cz - pz * w);
          nrm.push(0);
          nrm.push(1);
          nrm.push(0);
          nrm.push(0);
          nrm.push(1);
          nrm.push(0);
          var u = cum[k] / CityConfig.CELL;
          uv.push(u);
          uv.push(0);
          uv.push(u);
          uv.push(1);
          // vertex alpha = tail dissolve (t) * overall fade (1 while crawling, decays after a jump)
          var a = t * fade;
          col.push(1);
          col.push(1);
          col.push(1);
          col.push(a);
          col.push(1);
          col.push(1);
          col.push(1);
          col.push(a);
          // strip quad to the next point (two tris); winding irrelevant with DoubleSide. per-point Y +
          // the forced commit at a curb keep the rise sharp; depthTest off lets it drape over the curb
          if (k < n - 1)
            {
              var a = k * 2;
              idx.push(a);
              idx.push(a + 2);
              idx.push(a + 1);
              idx.push(a + 1);
              idx.push(a + 2);
              idx.push(a + 3);
            }
        }
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geo.setAttribute('normal', new Float32BufferAttribute(nrm, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
      geo.setAttribute('color', new Float32BufferAttribute(col, 4));
      geo.setIndex(idx);
      mesh.visible = true;
    }

// age + draw the render-only landing puddles through the shared paint surface (same green slime
// splat sprite as slime blood), fading over SLIME.puddleLifeMult; dead ones evicted
  function drawPuddles(dtMs:Float):Void
    {
      if (puddles.length == 0)
        return;
      var S = RenderConfig.SLIME;
      var step = dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      var tex = sprites.tex('entities', Const.SLIME_LARGE, Const.ROW_SPACESHIP2, false, RenderConfig.DECAL.bloodMul);
      var i = puddles.length - 1;
      while (i >= 0)
        {
          var p = puddles[i];
          p.age += step;
          var op = 1.0 - p.age / S.puddleLifeMult;
          if (op <= 0.0)
            {
              puddles.splice(i, 1);
              i--;
              continue;
            }
          if (tex != null)
            sprites.paint({
              x: p.x,
              y: p.y + S.yOff,
              z: p.z,
              tex: tex,
              op: op,
              scale: S.puddleScale,
              flat: true,
              order: Sprites.ORD_DECAL,
              emissive: RenderConfig.BLOOD.slimeGlow,
              emissiveInt: S.glowInt,
              rough: RenderConfig.BLOOD.wetRough,
              metal: RenderConfig.BLOOD.wetMetal,
            });
          i--;
        }
    }

// squared horizontal distance from a dx,dz pair
  inline function sq(dx:Float, dz:Float):Float
    {
      return dx * dx + dz * dz;
    }
}
