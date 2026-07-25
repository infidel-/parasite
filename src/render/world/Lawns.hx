package render.world;

import three.Three;
import citygen.CityConfig;
import citygen.CityModel.Tile;
import render.RenderConfig;
import render.Textures;
import render.Poly.tag;

// dead-lawn ground patches: ragged dry-grass cutouts laid over the alley cells around the slums
// house types, so a run-down cottage reads as sitting in what used to be a yard. render-only and
// deterministic (hashed off each footprint, no rng, no citygen desync) — the tile grid, walkability
// and the 2D map are untouched, these are just quads painted on top of the alley surface.
// No-op for any style that leaves lawnTex null (residential, downtown).
class Lawns {
  static inline var GRID = CityConfig.GRID;
  static inline var CELL = CityConfig.CELL;
  static inline var TILE = 6.0;  // world units per grass repeat — world-aligned on both axes, never stretched
  static inline var Y = 0.02;    // clear of the alley surface at y=0 (road markings prove 0.03 is plenty)

  public static function build(scene:Scene):Void {
    var st = WorldCtx.style;
    if (st.lawnTex == null ||
        st.lawnFacades == null)
      return;
    var tiles = WorldCtx.tiles;
    var half = (GRID * CELL) / 2;
    // one flag grid so two neighbouring houses sharing an alley cell don't emit it twice
    var taken = [for (_ in 0...GRID) [for (_ in 0...GRID) false]];
    var pos:Array<Float> = [];
    var uv:Array<Float> = [];
    var idx:Array<Int> = [];

    // one grass quad over cell (col,row), if it is a free alley cell
    inline function cell(col:Int, row:Int):Void {
      if (col < 0 ||
          row < 0 ||
          col >= GRID ||
          row >= GRID ||
          taken[row][col] ||
          tiles[row][col] != Tile.Alley)
        return;
      taken[row][col] = true;
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
    if (idx.length == 0)
      return;

    var geo = new BufferGeometry();
    geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
    geo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
    geo.setIndex(idx);
    geo.computeVertexNormals();
    var map = Textures.loadTexture(st.lawnTex, 'wall', 1);
    // alphaTest cutout (not blending): the patch edges are hand-ragged in the art, and a cutout
    // keeps them sorting-free against the alley underneath
    var mat = tag(new MeshStandardMaterial({ map: map, roughness: 1, metalness: 0,
      transparent: false, alphaTest: 0.5, side: THREE.DoubleSide }),
      'lawn', 'dead lawn grass', st.lawnTex);
    var mesh = new Mesh(geo, mat);
    // world-baked at the origin with no userData.b — it is ground, so it must NOT fade with any one
    // building. that puts it in __occ.skipped(), alongside the ground/kerb/markings meshes
    mesh.receiveShadow = true;
    scene.add(mesh);
  }
}
