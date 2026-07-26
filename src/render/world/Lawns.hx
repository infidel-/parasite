package render.world;

import three.Three;
import citygen.CityConfig;
import citygen.CityModel.Tile;
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
  static inline var TILE = 3.0;  // world units per grass repeat — world-aligned on both axes, never stretched.
                                 // below CELL (4) on purpose: the art is only ~40% opaque after the chroma key, so a
                                 // repeat WIDER than a cell left whole cells landing on its sparse gaps and reading
                                 // as bare alley. at 3 every cell gets more than a full repeat, hence some grass
  static inline var Y = 0.02;    // clear of the alley surface at y=0 (road markings prove 0.03 is plenty)
  static inline var ALPHA = 0.5; // base opacity — the grass is a translucent overlay, the alley reads through it
  static inline var EDGE = 0.15;   // vertex alpha on the outer rim of a patch (1.0 everywhere inside). multiplied into
                                   // the texture alpha, so the rim falls under alphaTest at its thinnest texels first and
                                   // the patch DISSOLVES outward along the art's own ragged shapes, not on a cell line
  static inline var FRINGE = 0.75; // how wide that dissolve is, world units. the ramp lives in a FRINGE-wide ring inset
                                   // into each border cell, NOT across the whole cell — a cell is CELL (4) units wide, and
                                   // ramping over all of it left the grass looking like it started a cell short of the
                                   // walkway instead of right where the walkway ends

  public static function build(scene:Scene):Void {
    var st = WorldCtx.style;
    if (st.lawnTex == null ||
        st.lawnFacades == null)
      return;
    var tiles = WorldCtx.tiles;
    var half = (GRID * CELL) / 2;
    // one flag grid: dedupes cells two neighbouring houses share, and pass 2 reads it back as the
    // patch shape to work out how far into the grass each corner sits
    var taken = [for (_ in 0...GRID) [for (_ in 0...GRID) false]];

    // pass 1 — mark every alley cell that some qualifying house claims as its yard
    inline function cell(col:Int, row:Int):Void {
      if (col >= 0 &&
          row >= 0 &&
          col < GRID &&
          row < GRID &&
          tiles[row][col] == Tile.Alley)
        taken[row][col] = true;
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

    var pos:Array<Float> = [];
    var uv:Array<Float> = [];
    var col4:Array<Float> = [];
    var idx:Array<Int> = [];

    inline function lawnAt(c:Int, r:Int):Bool {
      return c >= 0 &&
             r >= 0 &&
             c < GRID &&
             r < GRID &&
             taken[r][c];
    }

    // pass 2 — one marked cell becomes a 4x4 vertex grid (9 quads): a FRINGE-wide rim inset all round,
    // full-strength grass inside it. only the rim vertices on a side where the patch actually ENDS take
    // the EDGE alpha, so two abutting lawn cells stay at 1.0 across their shared border and read as one
    // continuous field
    for (row in 0...GRID)
      for (col in 0...GRID) {
        if (!taken[row][col])
          continue;
        var x0 = col * CELL - half;
        var z0 = row * CELL - half;
        var xs = [x0, x0 + FRINGE, x0 + CELL - FRINGE, x0 + CELL];
        var zs = [z0, z0 + FRINGE, z0 + CELL - FRINGE, z0 + CELL];
        var base = Std.int(pos.length / 3);
        for (j in 0...4)
          for (i in 0...4) {
            // which cell(s) this vertex leans against: 0/3 are the two rim columns/rows, 1/2 are inside
            var dx = i == 0 ? -1 : (i == 3 ? 1 : 0);
            var dz = j == 0 ? -1 : (j == 3 ? 1 : 0);
            var open = (dx != 0 && !lawnAt(col + dx, row)) ||
                       (dz != 0 && !lawnAt(col, row + dz)) ||
                       (dx != 0 && dz != 0 && !lawnAt(col + dx, row + dz));
            pos.push(xs[i]);
            pos.push(Y);
            pos.push(zs[j]);
            // uv straight off world position → the patches read as one continuous overgrown field
            // across abutting cells instead of a repeating per-cell stamp
            uv.push(xs[i] / TILE);
            uv.push(zs[j] / TILE);
            col4.push(1);
            col4.push(1);
            col4.push(1);
            col4.push(open ? EDGE : 1.0);
          }
        for (j in 0...3)
          for (i in 0...3) {
            var v = base + j * 4 + i;
            idx.push(v); idx.push(v + 5); idx.push(v + 1);
            idx.push(v); idx.push(v + 4); idx.push(v + 5);
          }
      }
    if (idx.length == 0)
      return;

    var geo = new BufferGeometry();
    geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
    geo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
    geo.setAttribute('color', new Float32BufferAttribute(col4, 4)); // itemSize 4 → three enables USE_COLOR_ALPHA
    geo.setIndex(idx);
    geo.computeVertexNormals();
    var map = Textures.loadTexture(st.lawnTex, 'wall', 1);
    // blended, not a hard cutout: the grass is a half-transparent overlay so the alley shows through it.
    // alphaTest still runs, scaled by ALPHA so exactly the texels that used to survive still do — it is
    // what turns the vertex-alpha border ramp into a ragged dissolve instead of a visible soft rectangle
    var mat = tag(new MeshStandardMaterial({ map: map, roughness: 1, metalness: 0,
      transparent: true, opacity: ALPHA, alphaTest: ALPHA * 0.5, depthWrite: false,
      vertexColors: true, side: THREE.DoubleSide }),
      'lawn', 'dead lawn grass', st.lawnTex);
    var mesh = new Mesh(geo, mat);
    mesh.renderOrder = render.particles.Sprites.ORD_DECAL - 1; // under blood/debris — it is ground, not a decal
    // world-baked at the origin with no userData.b — it is ground, so it must NOT fade with any one
    // building. that puts it in __occ.skipped(), alongside the ground/kerb/markings meshes
    mesh.receiveShadow = true;
    scene.add(mesh);
  }
}
