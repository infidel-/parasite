package render.world;

import three.Three;
import citygen.CityConfig;
import citygen.CityModel.Tile;
import render.Textures;
import render.Poly.tag;

// dead-lawn ground patches: ragged dry-grass cutouts laid over the alley cells around the slums
// house types, so a run-down cottage reads as sitting in what used to be a yard, plus stray clumps
// out in the courtyards where nothing has been mown in years. render-only and
// deterministic (hashed off each footprint, no rng, no citygen desync) — the tile grid, walkability
// and the 2D map are untouched, these are just quads painted on top of the alley surface.
// No-op for any style that leaves lawnTex null (residential, downtown).
//
// The SHAPE of a patch does not come from the cells it covers. Cells only say WHERE grass may be
// drawn; the outline is a coverage mask baked to a canvas (one soft radial kernel per marked cell,
// unioned) and handed to the material as alphaMap. So the visible boundary is a smooth round contour
// that owes nothing to the tile axes — the cell grid never shows through as a straight 4-unit edge.
class Lawns {
  static inline var GRID = CityConfig.GRID;
  static inline var CELL = CityConfig.CELL;
  static inline var TILE = 3.0;      // world units per grass repeat — world-aligned on both axes, never stretched.
                                     // below CELL (4) on purpose: the art is only ~40% opaque after the chroma key, so a
                                     // repeat WIDER than a cell left whole cells landing on its sparse gaps and reading
                                     // as bare alley. at 3 every cell gets more than a full repeat, hence some grass
  static inline var Y = 0.02;        // clear of the alley surface at y=0 (road markings prove 0.03 is plenty)
  static inline var ALPHA = 0.5;     // base opacity — the grass is a translucent overlay, the alley reads through it
  static inline var MASK_PX = 1024;  // coverage-mask canvas edge; it covers the WHOLE city rect, so this is ~0.4 world
                                     // units per texel. the field it holds is a smooth ramp, so bilinear reconstruction
                                     // is near-exact and the contour stays curved even at this resolution
  static inline var KERN = 7.0;      // kernel radius in world units. the grass survives alphaTest down to roughly
                                     // mask 0.55, so a lone marked cell reads as a blob of radius ~KERN*0.45. it has to
                                     // stay comfortably above CELL*0.5 or neighbouring kernels pinch at their waist and
                                     // a run of marked cells beads into a string of pearls instead of one lumpy band
  static inline var KERN_JIT = 0.35; // per-cell jitter of that radius and of the kernel centre, as a fraction. without
                                     // it every blob is the same circle on the same lattice, which reads as a pattern
  static inline var MIN_COURT = 6;   // alley cells below which a flood-filled region is a sliver, not a courtyard

  // the coverage mask is baked per area and is NOT one of the shared cached textures, so
  // View.disposeScene (which deliberately skips textures) will not free it — do it here
  static var maskTex:Texture = null;

  public static function build(scene:Scene):Void {
    if (maskTex != null) {
      maskTex.dispose();
      maskTex = null;
    }
    var st = WorldCtx.style;
    if (st.lawnTex == null ||
        st.lawnFacades == null)
      return;
    var tiles = WorldCtx.tiles;
    var half = (GRID * CELL) / 2;
    // one flag grid: dedupes cells two neighbouring houses share, and everything downstream (the mask
    // kernels, the geometry apron) reads it back as the patch shape
    var taken = [for (_ in 0...GRID) [for (_ in 0...GRID) false]];

    inline function cell(col:Int, row:Int):Void {
      if (col >= 0 &&
          row >= 0 &&
          col < GRID &&
          row < GRID &&
          tiles[row][col] == Tile.Alley)
        taken[row][col] = true;
    }

    // mark a seed plus whichever of its 4 neighbours the spare bits of its hash pick — a seed becomes
    // a 1-5 cell clump instead of a lone square, so the blob it grows is lumpy rather than circular
    inline function seed(col:Int, row:Int, h:Int):Void {
      cell(col, row);
      if (((h >> 10) & 1) != 0)
        cell(col + 1, row);
      if (((h >> 11) & 1) != 0)
        cell(col - 1, row);
      if (((h >> 12) & 1) != 0)
        cell(col, row + 1);
      if (((h >> 13) & 1) != 0)
        cell(col, row - 1);
    }

    // pass 1 — the yard ring around every qualifying house
    for (b in WorldCtx.buildings) {
      if (st.lawnFacades.indexOf(b.facade) < 0)
        continue;
      // same footprint hash idiom as Geom.frontInfo / the grime + metal variant picks
      var h = ((b.col * 73856093) ^ (b.row * 19349663)) & 0x7fffffff;
      if ((h % 1000) >= st.lawnChance * 1000)
        continue;
      // the 8-neighbour ring around the footprint. the cell in FRONT is usually walkway (setback 1)
      // and sits a curb up, so in practice the lawn reads as side and back yard
      for (col in b.col - 1...b.col + b.w + 1) {
        cell(col, b.row - 1);
        cell(col, b.row + b.d);
      }
      for (row in b.row...b.row + b.d) {
        cell(b.col - 1, row);
        cell(b.col + b.w, row);
      }
    }

    // pass 2 — stray patches out in the courtyards, on alley cells no house claimed. multipliers differ
    // from the footprint hash above so patch placement does not correlate with which houses got a yard
    if (st.lawnPatchChance > 0)
      for (row in 0...GRID)
        for (col in 0...GRID) {
          if (tiles[row][col] != Tile.Alley)
            continue;
          var h = ((col * 40503803) ^ (row * 12582917)) & 0x7fffffff;
          if ((h % 1000) >= st.lawnPatchChance * 1000)
            continue;
          seed(col, row, h);
        }

    // pass 3 — a couple of patches in the middle of every courtyard, so an open yard is never bare.
    // an alley cell is by definition one that touches no road (CityGen), so a flood fill over them
    // returns exactly one component per block interior — that IS the courtyard, no citygen data needed
    var dirs = [[1, 0], [0, 1], [-1, 0], [0, -1]];
    if (st.lawnCourtPatches > 0) {
      var seen = [for (_ in 0...GRID) [for (_ in 0...GRID) false]];
      for (r0 in 0...GRID)
        for (c0 in 0...GRID) {
          if (seen[r0][c0] ||
              tiles[r0][c0] != Tile.Alley)
            continue;
          var comp = [[c0, r0]];
          seen[r0][c0] = true;
          var qi = 0;
          while (qi < comp.length) {
            var p = comp[qi++];
            for (d in dirs) {
              var cc = p[0] + d[0];
              var rr = p[1] + d[1];
              if (cc >= 0 &&
                  rr >= 0 &&
                  cc < GRID &&
                  rr < GRID &&
                  !seen[rr][cc] &&
                  tiles[rr][cc] == Tile.Alley) {
                seen[rr][cc] = true;
                comp.push([cc, rr]);
              }
            }
          }
          if (comp.length < MIN_COURT)
            continue;
          var mc = 0.0;
          var mr = 0.0;
          for (p in comp) {
            mc += p[0];
            mr += p[1];
          }
          mc /= comp.length;
          mr /= comp.length;
          // spread the patches off the centroid on opposite compass headings, so they read as two
          // clumps in the yard rather than one lump dead centre. hashed off the component's anchor
          // cell — deterministic, and neighbouring courtyards do not line up
          var h = ((c0 * 22699523) ^ (r0 * 32452867)) & 0x7fffffff;
          var spread = 1 + Std.int(Math.sqrt(comp.length) / 3);
          for (k in 0...st.lawnCourtPatches) {
            var d = dirs[(h + k * 2) % 4];
            var tc = mc + d[0] * spread;
            var tr = mr + d[1] * spread;
            // the component cell nearest that target — the target itself may be a building or outside
            var best = comp[0];
            var bestD = 1e9;
            for (p in comp) {
              var dd = (p[0] - tc) * (p[0] - tc) + (p[1] - tr) * (p[1] - tr);
              if (dd < bestD) {
                bestD = dd;
                best = p;
              }
            }
            seed(best[0], best[1], h >> k);
          }
        }
    }

    // --- the coverage mask: one soft radial kernel per marked cell, unioned onto a city-wide canvas.
    // 'lighten' is a per-channel MAX, so a kernel's reach is exactly its own radius however many
    // neighbours pile up; an additive composite would let the visible contour creep outward in dense
    // clusters until it spilled past the geometry below
    var px = MASK_PX / (GRID * CELL); // canvas pixels per world unit
    var cv = js.Browser.document.createCanvasElement();
    cv.width = MASK_PX;
    cv.height = MASK_PX;
    var ctx = cv.getContext2d();
    ctx.fillStyle = '#000000';
    ctx.fillRect(0, 0, MASK_PX, MASK_PX);
    ctx.globalCompositeOperation = 'lighten';
    var any = false;
    for (row in 0...GRID)
      for (col in 0...GRID) {
        if (!taken[row][col])
          continue;
        any = true;
        var h = ((col * 83492791) ^ (row * 51992411)) & 0x7fffffff;
        // three independent jitters off one hash: kernel centre in x and z, and its radius
        var jx = ((h & 63) / 63 - 0.5) * CELL * KERN_JIT;
        var jz = (((h >> 6) & 63) / 63 - 0.5) * CELL * KERN_JIT;
        var r = KERN * (1 + (((h >> 12) & 63) / 63 - 0.5) * 2 * KERN_JIT) * px;
        var cx = (col * CELL + CELL / 2 + jx) * px;
        var cy = (row * CELL + CELL / 2 + jz) * px;
        var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
        g.addColorStop(0, '#ffffff');
        g.addColorStop(1, '#000000');
        ctx.fillStyle = g;
        ctx.fillRect(cx - r, cy - r, r * 2, r * 2);
      }
    if (!any)
      return;

    // --- geometry: one quad per alley cell that is marked OR touches a marked one. the apron ring is
    // what lets a blob round off past its own cell; the mesh stopping at the alley is what keeps grass
    // off the walkway and the road, which is the one hard edge we want
    var pos:Array<Float> = [];
    var uv:Array<Float> = [];
    var idx:Array<Int> = [];
    inline function near(col:Int, row:Int):Bool {
      var hit = false;
      for (dr in -1...2)
        for (dc in -1...2)
          if (col + dc >= 0 &&
              row + dr >= 0 &&
              col + dc < GRID &&
              row + dr < GRID &&
              taken[row + dr][col + dc])
            hit = true;
      return hit;
    }
    for (row in 0...GRID)
      for (col in 0...GRID) {
        if (tiles[row][col] != Tile.Alley ||
            !near(col, row))
          continue;
        var x0 = col * CELL - half, x1 = x0 + CELL;
        var z0 = row * CELL - half, z1 = z0 + CELL;
        var base = Std.int(pos.length / 3);
        // uv straight off world position → the patches read as one continuous overgrown field
        // across abutting cells instead of a repeating per-cell stamp
        for (p in [[x0, z0], [x1, z0], [x1, z1], [x0, z1]]) {
          pos.push(p[0]);
          pos.push(Y);
          pos.push(p[1]);
          uv.push(p[0] / TILE);
          uv.push(p[1] / TILE);
        }
        idx.push(base); idx.push(base + 2); idx.push(base + 1);
        idx.push(base); idx.push(base + 3); idx.push(base + 2);
      }

    var geo = new BufferGeometry();
    geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
    geo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
    geo.setIndex(idx);
    geo.computeVertexNormals();
    var map = Textures.loadTexture(st.lawnTex, 'wall', 1);
    maskTex = new CanvasTexture(cv);
    // the mask rides on the SAME uv as the grass (alphaMap carries its own texture transform), so the
    // uv that tiles the grass every TILE units is rescaled here to span the city rect exactly once
    maskTex.flipY = false; // canvas row 0 == z = -half; a bare CanvasTexture defaults to true and would mirror it
    maskTex.repeat.set(TILE / (GRID * CELL), TILE / (GRID * CELL));
    maskTex.offset.set(0.5, 0.5);
    maskTex.needsUpdate = true;
    // blended, not a hard cutout: the grass is a half-transparent overlay so the alley shows through it.
    // alphaTest runs AFTER the alphaMap multiply, which is what turns the mask's smooth ramp into a
    // ragged dissolve along the art's own shapes instead of a visible soft blob
    var mat = tag(new MeshLambertMaterial({ map: map, alphaMap: maskTex,
      transparent: true, opacity: ALPHA, alphaTest: ALPHA * 0.5, depthWrite: false,
      side: THREE.DoubleSide }),
      'lawn', 'dead lawn grass', st.lawnTex);
    var mesh = new Mesh(geo, mat);
    mesh.renderOrder = render.particles.Sprites.ORD_DECAL - 1; // under blood/debris — it is ground, not a decal
    // world-baked at the origin with no userData.b — it is ground, so it must NOT fade with any one
    // building. that puts it in __occ.skipped(), alongside the ground/kerb/markings meshes
    mesh.receiveShadow = true;
    scene.add(mesh);
  }
}
