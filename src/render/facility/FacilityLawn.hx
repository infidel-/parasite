package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.wild.WildGrass;
import render.wild.WildStyle;
import render.world.CoverageMask;
import render.world.VisionMask;

// the park lawn's dressing: a ragged overlay of tall unmown grass over the mown turf, and a few
// standing tufts inside the same blobs. one flat map across a whole park reads as felt, and this is
// the idiom the rest of the game already answers that with.
//
// it is the THIRD caller of render.world.CoverageMask, after render.world.Lawns (slums back yards and
// city courtyards) and render.wild.WildPatches (the wilderness). those two hand-write their own
// geometry and material because theirs genuinely differ, and so does this one — a compound is FLAT,
// so it takes Lawns' single unsubdivided mesh rather than WildPatches' relief-following lattice, and
// every lit surface out here is mask-patched, so it takes WildPatches' material rather than Lawns'
// bare one. what is SHARED is the one piece that was worth extracting: the coverage bake.
//
// the tufts are not a copy of render.wild.WildGrass, they are calls into it. its tuft() writes
// normals pointing straight UP rather than out of each quad's face, and its material() cancels
// three's DOUBLE_SIDED flip of exactly that — one mechanism written in two places, and a second copy
// would drift out of step and split the field into a light half and a dark half that reshuffles as
// the camera turns, which is the failure those two halves exist to prevent.
class FacilityLawn
{
  static inline var CELL = CityConfig.CELL;

  // the baked coverage field, held so the next build can free it: render.View.disposeScene
  // deliberately skips textures, and this is a per-area canvas rather than shared cached art (Lawns
  // and WildPatches hold their own for the same reason)
  static var maskTex:Texture = null;
  // what the last build marked and planted, for __facility(). the lawn's own cell bounds ride along
  // because the coverage canvas spans the WHOLE area rect: measured over that, a park's patches are
  // a fraction of a percent whatever they do, and the one number this layer is tuned on says nothing
  static var cells = 0;
  static var tufts = 0;
  static var lawn = 0;
  static var c0 = 0;
  static var r0 = 0;
  static var c1 = 0;
  static var r1 = 0;

// the overlay layer and the tufts standing in it. `area` is null in the boot warm scene, which has no
// game area behind its demo model — the same null render.facility.FacilityDoors.build already takes
  public static function build(scene:Scene, m:Facility, ?area:game.AreaGame):Void
    {
      if (maskTex != null)
        {
          maskTex.dispose();
          maskTex = null;
        }
      cells = 0;
      tufts = 0;
      lawn = 0;
      c0 = m.w;
      r0 = m.h;
      c1 = 0;
      r1 = 0;
      // pass 1 — find the lawn and its bounds. the lattice below is anchored to them, so two
      // compounds whose parks sit at different offsets get different patterns for free
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.GRASS)
              continue;
            lawn++;
            if (col < c0)
              c0 = col;
            if (row < r0)
              r0 = row;
            if (col + 1 > c1)
              c1 = col + 1;
            if (row + 1 > r1)
              r1 = row + 1;
          }
      if (lawn == 0)
        return;
      // pass 2 — which lawn cells the patch may cover: ONE seed per PATCH_STEP block, placed inside
      // its own block by the hash, then marking itself plus whichever of its four neighbours the
      // spare bits pick, so a seed becomes a 1-5 cell clump and the blob the mask grows off it comes
      // out lumpy instead of circular (Lawns' idiom, and WildPatches' after it).
      //
      // STRATIFIED, where both of those roll independently per cell, and FacilityStyle.PATCH_STEP
      // carries the measurement that forced it: nine independent samples over a park this size clump
      // badly enough to leave whole columns of lawn flat. deterministic either way, so a park saved
      // before today gets its patches on re-entry with nothing persisted
      var taken = [for (_ in 0...m.h) [for (_ in 0...m.w) false]];
      var S = FacilityStyle.PATCH_STEP;
      var brow = r0;
      while (brow < r1)
        {
          var bcol = c0;
          while (bcol < c1)
            {
              var h = FacilityModel.mix((bcol * 40503803) ^ (brow * 12582917));
              var col = bcol + h % S;
              var row = brow + (h >> 8) % S;
              // the pick can land on the park path, on a cell past the lawn's ragged edge, or outside
              // the bounds entirely — that block simply grows nothing, which is what keeps the patches
              // inside the lawn without a second predicate
              mark(taken, m, col, row);
              if (((h >> 20) & 1) != 0)
                mark(taken, m, col + 1, row);
              if (((h >> 21) & 1) != 0)
                mark(taken, m, col - 1, row);
              if (((h >> 22) & 1) != 0)
                mark(taken, m, col, row + 1);
              if (((h >> 23) & 1) != 0)
                mark(taken, m, col, row - 1);
              bcol += S;
            }
          brow += S;
        }
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (taken[row][col])
            cells++;
      maskTex = CoverageMask.bake(taken, FacilityStyle.PATCH_TILE, FacilityStyle.PATCH_KERN,
        FacilityStyle.PATCH_KERN_JIT);
      if (maskTex == null)
        return;
      overlay(scene, m, taken);
      grass(scene, m, taken, area);
    }

// the overlay quads: one per lawn cell that is marked OR touches a marked one, a hair over the turf.
// the apron ring is what lets a blob round off past its own cell instead of being clipped square by
// it, and stopping at Surf.GRASS is what keeps the patch off the park path, the kerb and the lot —
// the path is written as plain walkway by the generator, so it needs no gate of its own
  static function overlay(scene:Scene, m:Facility, taken:Array<Array<Bool>>):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var y = FacilityGround.surfY(Surf.GRASS) + FacilityStyle.PATCH_Y;
      var pos = [];
      var uv = [];
      var idx = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.GRASS
              || !near(taken, col, row))
              continue;
            var x0 = col * CELL - half;
            var x1 = x0 + CELL;
            var z0 = row * CELL - half;
            var z1 = z0 + CELL;
            var base = Std.int(pos.length / 3);
            // uv straight off world position, so abutting cells read as one continuous overgrown
            // field rather than a per-cell stamp — and nothing is stretched on either axis
            for (p in [[x0, z0], [x1, z0], [x1, z1], [x0, z1]])
              {
                pos.push(p[0]);
                pos.push(y);
                pos.push(p[1]);
                uv.push(p[0] / FacilityStyle.PATCH_TILE);
                uv.push(p[1] / FacilityStyle.PATCH_TILE);
              }
            idx.push(base);
            idx.push(base + 2);
            idx.push(base + 1);
            idx.push(base);
            idx.push(base + 3);
            idx.push(base + 2);
          }
      if (idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
      geo.setIndex(idx);
      geo.computeVertexNormals();
      // blended and not a hard cutout: the patch is a half-transparent overlay so the mown lawn shows
      // through it. alphaTest runs AFTER the alphaMap multiply, which is what turns the mask's smooth
      // ramp into a ragged dissolve along the ART's own island shapes instead of a visible soft blob.
      // FrontSide, where Lawns takes DoubleSide — this only ever faces up
      var mesh = new Mesh(geo, VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(FacilityStyle.PATCH_LUSH, 'wall', 1),
        alphaMap: maskTex,
        transparent: true,
        opacity: FacilityStyle.PATCH_ALPHA,
        alphaTest: FacilityStyle.PATCH_ALPHA * 0.5,
        depthWrite: false,
        side: THREE.FrontSide,
      })));
      mesh.renderOrder = render.particles.Sprites.ORD_DECAL - 1; // under blood and debris: it is ground, not a decal
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// the standing tufts, on the cells the overlay already marked. tying them to `taken` rather than
// rolling again is what keeps them to "a few" for nothing AND puts the tall grass where the tall
// grass is painted — the two layers would otherwise disagree about which part of the lawn was unmown.
//
// one merged mesh, not a chunked one: every facility mesh is already past render.Chunks' 16-cell size
// guard and sits at the scene root, so a chunked layer here would be rejected anyway
  static function grass(scene:Scene, m:Facility, taken:Array<Array<Bool>>, area:game.AreaGame):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var y = FacilityGround.surfY(Surf.GRASS);
      var pos = [];
      var nor = [];
      var uv = [];
      var wind = [];
      var idx = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.GRASS)
              continue;
            // a tree, a bush or a bench stands on its cell, and blades pushing up through a trunk or
            // a seat read as grass growing out of it. only the PLAIN lawn tile grows tufts — and the
            // warm scene has no area behind its demo model, where every grass cell is plain lawn
            if (area != null
              && area.getCellType(col, row) != Const.TILE_GRASS)
              continue;
            // denser where the overlay says the grass is long, thinner on the mown lawn between the
            // trees — but never nothing out there, which is where the felt was
            var n = taken[row][col] ? FacilityStyle.TUFT_PATCH : FacilityStyle.TUFT_LAWN;
            // its own multipliers, mixed: must not correlate with the patch roll over the same cell
            var h = FacilityModel.mix((col * 19349663) ^ (row * 83492791));
            for (k in 0...n)
              {
                h = FacilityModel.mix(h);
                // inset from the cell edge, so a tuft never straddles into a neighbour that is path,
                // pavement or a planted cell
                var px = (col + 0.15 + (h % 701) / 701.0 * 0.7) * CELL - half;
                var pz = (row + 0.15 + ((h >> 9) % 701) / 701.0 * 0.7) * CELL - half;
                var s = 1.0 + (((h >> 17) % 2001) / 1000.0 - 1.0) * WildStyle.TUFT_JITTER;
                WildGrass.tuft({
                  pos: pos,
                  nor: nor,
                  uv: uv,
                  wind: wind,
                  idx: idx,
                  x: px,
                  // a compound has no relief, so this is the lawn's own constant height rather than a
                  // sample — the whole reason WildGrass.tuft takes it from the caller now
                  y: y,
                  z: pz,
                  yaw: ((h >> 3) % 3600) / 3600.0 * Math.PI,
                  w: WildStyle.TUFT_W * s,
                  h: FacilityStyle.TUFT_H * s,
                  hash: h,
                });
                tufts++;
              }
          }
      if (idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geo.setAttribute('normal', new Float32BufferAttribute(nor, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
      geo.setAttribute('aWind', new Float32BufferAttribute(wind, 2));
      geo.setIndex(idx);
      var mesh = new Mesh(geo, WildGrass.material(WildStyle.WIND_RATE * FacilityStyle.TUFT_WIND_MUL));
      // receives, never casts — the reason WildGrass gives: a shadow-casting grass field doubles the
      // depth pass over alpha-tested triangles to produce a mat of noise nobody reads as a shadow
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// what the last build laid down, for __facility(). `strong` is the share of the PARK that clears
// alphaTest, and it is the only number this layer can be tuned on: the wilderness pass got the same
// judgement wrong twice by eye, because what shows through a near-uniform coverage field is the ART's
// own ~41% opacity — grain over the whole lawn — and tinting the layer to look at it says only that
// it is everywhere.
//
// over the LAWN'S OWN BOUNDS and not the canvas, which spans the whole 400-unit area rect: measured
// there a park's blobs are a fraction of a percent however overgrown they are. read off the retained
// canvas rather than counted at bake time, so it stays true to the texture the material samples
  public static function stats():Dynamic
    {
      var strong = 0.0;
      if (maskTex != null
        && c1 > c0)
        {
          var cv:js.html.CanvasElement = cast maskTex.image;
          var px = cv.width / (CityConfig.GRID * CELL); // canvas texels per world unit
          var x0 = Math.round(c0 * CELL * px);
          var y0 = Math.round(r0 * CELL * px);
          var w = Math.round(c1 * CELL * px) - x0;
          var h = Math.round(r1 * CELL * px) - y0;
          var d = cv.getContext2d().getImageData(x0, y0, w, h).data;
          var n = 0;
          var i = 0;
          while (i < d.length)
            {
              if (d[i] >= 255 * FacilityStyle.PATCH_ALPHA * 0.5)
                n++;
              i += 4;
            }
          strong = 100.0 * n / (w * h);
        }
      return {
        tex: FacilityStyle.PATCH_LUSH,
        lawn: lawn,
        cells: cells,
        strong: strong,
        tufts: tufts,
      };
    }

// mark a cell, if it is on the grid and is lawn
  static inline function mark(taken:Array<Array<Bool>>, m:Facility, col:Int, row:Int):Void
    {
      if (FacilityModel.inside(m, col, row)
        && m.surf[row][col] == Surf.GRASS)
        taken[row][col] = true;
    }

// is (col,row) marked, or one of its eight neighbours?
  static function near(taken:Array<Array<Bool>>, col:Int, row:Int):Bool
    {
      for (dr in -1...2)
        for (dc in -1...2)
          {
            var c = col + dc;
            var r = row + dr;
            if (r >= 0
              && r < taken.length
              && c >= 0
              && c < taken[r].length
              && taken[r][c])
              return true;
          }
      return false;
    }
}
