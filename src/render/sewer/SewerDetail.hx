package render.sewer;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.Textures;
import render.sewer.SewerModel.Sewer;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// dressing laid over the SewerGeom shell, and the reason the shell can get away with a single wall
// texture: a damp grime band at the foot of every wall, and fake contact shadows where wall meets
// floor. all of it is derived from the cell grid, deterministic, and persisted nowhere.
//
// this replaces per-cell texture VARIETY with per-cell OVERLAYS. swapping whole wall tiles put a
// hard seam on ~47% of cell boundaries (see SewerStyle.WALL); overlays cannot seam, because the
// base under them is continuous and world-tiled
class SewerDetail
{
  static inline var CELL = CityConfig.CELL;

// all sewer dressing into the scene
  public static function build(scene:Scene, m:Sewer):Void
    {
      grime(scene, m);
      shadows(scene, m);
      decals(scene, m);
    }

// ---------------------------------------------------------------------------------------------
// wall detail decals — the wear that used to be a whole second wall texture. ported from
// render.world.WallDecals, minus everything the city needs and a sewer does not: no worn-face test
// (every tunnel wall is bare), no door spans to dodge, no userData.b (nothing fades underground).
//
// the one real change is batching. WallDecals emits one Mesh PER DECAL because Occlusion has to
// fade each with its building; with no occlusion pass down here they merge per image instead, so
// the whole level costs one draw call per decal image rather than one per decal
  static function decals(scene:Scene, m:Sewer):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      // size band (lo..hi), height off the floor, and albedo tint per category. seepage alone is
      // tinted: it is chalky off-white while every wall texture is authored dark for the night
      // palette, so untinted it reads as lit from nowhere — the same reason WallDecals tints its
      // posters and graffiti but leaves cracks alone. the rest already sit in the wall's range
      var cats = [
        { tex: SewerStyle.CRACK, lo: 1.4, hi: 2.2, baseY: 0.4, tint: 0xffffff },
        { tex: SewerStyle.SEEPAGE, lo: 1.4, hi: 2.2, baseY: 0.7, tint: RenderConfig.WALLDECAL_TINT },
        { tex: SewerStyle.MOSS, lo: 1.2, hi: 2.0, baseY: 0.2, tint: 0xffffff },
        { tex: SewerStyle.BROKEN, lo: 1.2, hi: 2.0, baseY: 0.5, tint: 0xffffff },
      ];
      var bufs = [for (_ in cats) MeshBufTools.make()];
      var H = SewerStyle.WALL_H;
      var eps = SewerStyle.DECAL_EPS;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!m.floor[row][col])
              continue;
            var x0 = col * CELL - half, x1 = x0 + CELL;
            var z0 = row * CELL - half, z1 = z0 + CELL;
            for (dir in 0...4)
              {
                var dc = (dir == 2 ? -1 : (dir == 3 ? 1 : 0));
                var dr = (dir == 0 ? -1 : (dir == 1 ? 1 : 0));
                if (SewerModel.isFloor(m, col + dc, row + dr))
                  continue;
                // decision hash off this FACE (cell + dir), the WallDecals idiom with its own
                // multipliers. deterministic, so a tunnel is decorated identically every reload.
                // mixed, and not optional: raw, this hash combs the area border — on row 0 the row
                // term vanishes and it reduces to col * 92821, which at 18% placed decals on cols
                // 0, 5, 10, 15, 24, 29, 34 (see SewerModel.mix, where the ledge case is measured)
                var hh = SewerModel.mix((col * 92821) ^ (row * 68917) ^ (dir * 40503));
                if (hh % 100 >= SewerStyle.DECAL_PCT)
                  continue;
                var ci = (hh >> 3) % cats.length;
                var cat = cats[ci];
                var s = cat.lo + ((hh >> 11) % 1000) / 1000.0 * (cat.hi - cat.lo);
                // a face is only CELL wide and WALL_H tall, so clamp hard: the quad must clear the
                // cell's side edges (or it would cut into the neighbouring face at a right angle)
                // and stay off the floor and the ledge cap
                var span = CELL - 2 * SewerStyle.DECAL_MARGIN;
                if (s > span)
                  s = span;
                if (s > H)
                  s = H;
                var off = (((hh >> 14) % 1000) / 1000.0 - 0.5) * (span - s);
                var y = cat.baseY + s / 2 + ((hh >> 18) % 100) / 100.0 * 0.5;
                if (y + s / 2 > H)
                  y = H - s / 2;
                if (y - s / 2 < 0)
                  y = s / 2;
                face(bufs[ci], dir, x0, x1, z0, z1, off, y, s, eps);
              }
          }
      for (i in 0...cats.length)
        {
          if (bufs[i].idx.length == 0)
            continue;
          var geo = new BufferGeometry();
          geo.setAttribute('position', new Float32BufferAttribute(bufs[i].pos, 3));
          geo.setAttribute('uv', new Float32BufferAttribute(bufs[i].uv, 2));
          geo.setIndex(bufs[i].idx);
          geo.computeVertexNormals();
          var mesh = new Mesh(geo, new MeshLambertMaterial({
            map: Textures.loadTexture(cats[i].tex, 'wall'),
            color: cats[i].tint,
            transparent: true,
            alphaTest: 0.35,
            depthWrite: false,
            side: THREE.FrontSide,
            polygonOffset: true,
            polygonOffsetFactor: -2, // proud of the grime band's -1, so a decal wins over the muck
            polygonOffsetUnits: -2,
          }));
          mesh.receiveShadow = true;
          scene.add(mesh);
        }
    }

// one decal quad on a cell's wall face, `off` along the face and centred at height `y`, set `eps`
// proud of the wall. wound to face into the cell, matching SewerGeom.side's four directions
  static function face(b:MeshBuf, dir:Int, x0:Float, x1:Float, z0:Float, z1:Float,
    off:Float, y:Float, s:Float, eps:Float):Void
    {
      var h = s / 2;
      var cx = (x0 + x1) / 2 + off;
      var cz = (z0 + z1) / 2 + off;
      var uv = [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0];
      switch (dir)
        {
          case 0:
            var z = z0 + eps;
            MeshBufTools.quad(b, [cx - h, y - h, z], [cx + h, y - h, z], [cx + h, y + h, z], [cx - h, y + h, z], uv);
          case 1:
            var z = z1 - eps;
            MeshBufTools.quad(b, [cx + h, y - h, z], [cx - h, y - h, z], [cx - h, y + h, z], [cx + h, y + h, z], uv);
          case 2:
            var x = x0 + eps;
            MeshBufTools.quad(b, [x, y - h, cz + h], [x, y - h, cz - h], [x, y + h, cz - h], [x, y + h, cz + h], uv);
          default:
            var x = x1 - eps;
            MeshBufTools.quad(b, [x, y - h, cz - h], [x, y - h, cz + h], [x, y + h, cz + h], [x, y + h, cz - h], uv);
        }
    }

// ---------------------------------------------------------------------------------------------
// damp band at the foot of every wall, now exactly what render.world.Buildings does at street level:
// the alpha is HAND-PAINTED into the source, not a code ramp.
//
// it started as a code-generated alpha ramp over an opaque tile, and that is why it read vague — a
// vertical ramp gives every texel at a given height the same alpha, so the band had no shape of its
// own, only a gradient wash. painted alpha puts the drips, blooms and damp patches in the alpha
// channel where they can read as separate stains.
//
// which brings the premultiply with it: hand-painted alpha carries saturated junk RGB under its
// near-transparent texels, and straight-alpha filtering bleeds that out as coloured specks once
// minified. wrapT clamps because v spans the ramp exactly once
  static function grime(scene:Scene, m:Sewer):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var b = MeshBufTools.make();
      var H = SewerStyle.GRIME_H;
      var t = SewerStyle.GRIME_TILE;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!m.floor[row][col])
              continue;
            var x0 = col * CELL - half, x1 = x0 + CELL;
            var z0 = row * CELL - half, z1 = z0 + CELL;
            // same four faces SewerGeom walls, wound the same way (inward), just shorter. u is
            // world-derived so the muck never stretches and runs continuously between cells; v
            // spans the whole ramp exactly once, which is why the texture clamps vertically
            if (!SewerModel.isFloor(m, col, row - 1))
              MeshBufTools.quad(b, [x0, 0, z0], [x1, 0, z0], [x1, H, z0], [x0, H, z0],
                [x0 / t, 0, x1 / t, 0, x1 / t, 1, x0 / t, 1]);
            if (!SewerModel.isFloor(m, col, row + 1))
              MeshBufTools.quad(b, [x1, 0, z1], [x0, 0, z1], [x0, H, z1], [x1, H, z1],
                [x1 / t, 0, x0 / t, 0, x0 / t, 1, x1 / t, 1]);
            if (!SewerModel.isFloor(m, col - 1, row))
              MeshBufTools.quad(b, [x0, 0, z1], [x0, 0, z0], [x0, H, z0], [x0, H, z1],
                [z1 / t, 0, z0 / t, 0, z0 / t, 1, z1 / t, 1]);
            if (!SewerModel.isFloor(m, col + 1, row))
              MeshBufTools.quad(b, [x1, 0, z0], [x1, 0, z1], [x1, H, z1], [x1, H, z0],
                [z0 / t, 0, z1 / t, 0, z1 / t, 1, z0 / t, 1]);
          }
      if (b.idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      var tex = Textures.loadTexture(SewerStyle.GRIME, 'wall');
      tex.premultiplyAlpha = true;
      tex.wrapT = THREE.ClampToEdgeWrapping;
      tex.needsUpdate = true;
      // every band in the level on ONE material and ONE mesh: one draw call however big the sewer
      var mesh = new Mesh(geo, new MeshLambertMaterial({
        map: tex,
        transparent: true,
        premultipliedAlpha: true,
        opacity: SewerStyle.GRIME_OPACITY,
        depthWrite: false,
        side: THREE.FrontSide,
        polygonOffset: true,
        polygonOffsetFactor: -1,
        polygonOffsetUnits: -1,
      }));
      mesh.receiveShadow = true;
      scene.add(mesh);
    }

// ---------------------------------------------------------------------------------------------
// fake contact shadow where a wall meets the floor. ported from render.world.roofs.RoofShadows,
// which does the same thing under a building parapet, and it needs NO art at all: both gradients
// are drawn onto a canvas at runtime by Textures.makeShadowGradient / makeRadialShadowGradient.
//
// RoofShadows spends most of its length deriving WHERE a parapet exists along a merged building
// outline (coveredEdges / exposedSpans / cornerBuried). underground the cell grid already says it,
// so this is just two passes over the cells:
//   strip  — a floor cell with an orthogonal solid neighbour, laid along that wall
//   radial — a floor cell whose DIAGONAL neighbour alone is solid. that is the one nook two
//            perpendicular strips cannot reach; at an ordinary inside corner the two strips already
//            overlap, and their blend is the corner darkening, so a radial there would double-darken
  static function shadows(scene:Scene, m:Sewer):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var W = SewerStyle.SHADOW_W;
      var y = SewerStyle.SHADOW_Y;
      var stripM:Array<Matrix4> = [];
      var cornM:Array<Matrix4> = [];
      var q = new Quaternion();
      // -90 deg about X lays the plane flat and points its normal at +Y. it also sends the quad's
      // local +Y (uv v=1, the transparent end of both gradients) to world -Z, which is what every
      // yaw below is reasoning against
      var qx = new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), -Math.PI / 2);
      var up = new Vector3(0, 1, 0);
      var pos = new Vector3();
      var scl = new Vector3();
      inline function push(arr:Array<Matrix4>, sx:Float, sz:Float, yaw:Float, px:Float, pz:Float):Void
        {
          q.setFromAxisAngle(up, yaw).multiply(qx);
          pos.set(px, y, pz);
          scl.set(sx, sz, 1);
          arr.push(new Matrix4().compose(pos, q, scl));
        }
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!m.floor[row][col])
              continue;
            var x0 = col * CELL - half, x1 = x0 + CELL;
            var z0 = row * CELL - half, z1 = z0 + CELL;
            var xc = (x0 + x1) / 2, zc = (z0 + z1) / 2;
            // strips. yaw turns the gradient's opaque end toward the wall: with v=1 landing on -Z
            // at yaw 0, a wall on the -Z side needs a half turn, and the x walls a quarter each
            if (!SewerModel.isFloor(m, col, row - 1))
              push(stripM, CELL, W, Math.PI, xc, z0 + W / 2);
            if (!SewerModel.isFloor(m, col, row + 1))
              push(stripM, CELL, W, 0, xc, z1 - W / 2);
            if (!SewerModel.isFloor(m, col - 1, row))
              push(stripM, CELL, W, -Math.PI / 2, x0 + W / 2, zc);
            if (!SewerModel.isFloor(m, col + 1, row))
              push(stripM, CELL, W, Math.PI / 2, x1 - W / 2, zc);
            // diagonal-only corners. the radial gradient is opaque at uv(1,0), which after the flat
            // rotation points at world (+X,+Z), so each yaw below aims that corner at its own solid
            var R = W * 0.7; // a touch tighter than the strips so it never overgrows the band
            inline function diag(dc:Int, dr:Int, yaw:Float, px:Float, pz:Float):Void
              {
                if (SewerModel.isFloor(m, col + dc, row + dr) ||
                    !SewerModel.isFloor(m, col + dc, row) ||
                    !SewerModel.isFloor(m, col, row + dr))
                  return;
                push(cornM, R, R, yaw, px, pz);
              }
            diag(-1, -1, Math.PI, x0 + R / 2, z0 + R / 2);
            diag(1, -1, Math.PI / 2, x1 - R / 2, z0 + R / 2);
            diag(-1, 1, -Math.PI / 2, x0 + R / 2, z1 - R / 2);
            diag(1, 1, 0.0, x1 - R / 2, z1 - R / 2);
          }
      var geo = new PlaneGeometry(1, 1);
      // FrontSide, unlike the RoofShadows original: the quads lie flat with their normal at +Y and
      // the camera is always above them, so the back face is never seen. three draws a transparent
      // DoubleSide material as TWO single-side passes (see the gas entry in docs/3d-render.md), so
      // this is worth 2 draw calls here — measured 36 -> 34 in the habitat, one per instanced set.
      // it did NOT change the first-entry program count, so the saving is calls, not compiles
      inline function mat(alphaMap:Texture):MeshBasicMaterial return new MeshBasicMaterial({
        color: 0x000000,
        alphaMap: alphaMap,
        transparent: true,
        opacity: SewerStyle.SHADOW_ALPHA,
        depthWrite: false,
        side: THREE.FrontSide,
      });
      // one InstancedMesh each: two draw calls for every contact shadow in the level, and since
      // the whole sewer is one instanced batch there is no per-instance culling cost to pay
      var sets = [
        { mats: stripM, tex: Textures.makeShadowGradient() },
        { mats: cornM, tex: Textures.makeRadialShadowGradient() },
      ];
      for (s in sets)
        {
          if (s.mats.length == 0)
            continue;
          var mesh = new InstancedMesh(geo, mat(s.tex), s.mats.length);
          for (k in 0...s.mats.length)
            mesh.setMatrixAt(k, s.mats[k]);
          mesh.instanceMatrix.needsUpdate = true;
          scene.add(mesh);
        }
    }
}
