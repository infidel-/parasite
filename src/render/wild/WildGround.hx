package render.wild;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.wild.WildModel.Wild;

// the wilderness ground: one SUBDIVIDED, shared-vertex, per-vertex-tinted grid per chunk block.
//
// three deliberate differences from render.world.Ground and render.sewer.SewerGeom, which both lay
// one flat quad per cell:
//  - SUBDIVIDED. a 4-unit quad with a tiling texture on it reads as a tile, and out here there is no
//    kerb, no road paint and no building edge to break the repeat up. WildStyle.SUB sub-quads per
//    axis give the surface something to vary ACROSS.
//  - SHARED VERTICES, and therefore not render.world.MeshBuf, which emits four unshared vertices per
//    quad. that is right for flat city ground and wrong here: the lattice is displaced into relief by
//    render.wild.WildHeight, and unshared corners would give the surface a faceted crease along every
//    sub-quad edge whatever the normals said.
//  - PER-CHUNK. at SUB 2 the whole area is 200x200 quads = 80k tris, so it is emitted as one mesh
//    per render.Chunks.CELLS block: an offscreen block is then one bounding-sphere reject instead of
//    40k triangles walked. every block shares ONE material, so this is one program and the blocks
//    batch together in the sort
class WildGround
{
  static inline var CELL = CityConfig.CELL;

// emit the ground, one mesh per chunk block
  public static function build(scene:Scene, m:Wild):Void
    {
      var B = render.Chunks.CELLS;
      // one material for every block: the tint that varies them is per-vertex, so nothing here is
      // per-block except the geometry
      var mat = new MeshLambertMaterial({
        map: Textures.loadTexture(WildStyle.GROUND, 'asphalt', 1),
        side: THREE.FrontSide,
        vertexColors: true,
      });
      var row = 0;
      while (row < m.h)
        {
          var col = 0;
          while (col < m.w)
            {
              block(scene, mat, col, row,
                (col + B <= m.w) ? B : m.w - col,
                (row + B <= m.h) ? B : m.h - row);
              col += B;
            }
          row += B;
        }
    }

// one chunk block, as a welded indexed grid of cw x ch cells at SUB sub-quads per axis
  static function block(scene:Scene, mat:MeshLambertMaterial, col0:Int, row0:Int, cw:Int, ch:Int):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var S = WildStyle.SUB;
      var nx = cw * S;
      var nz = ch * S;
      var pos = [];
      var nor = [];
      var uv = [];
      var colr = [];
      // the lattice. every vertex is derived from its WORLD position alone, so the boundary row two
      // neighbouring blocks both emit lands on identical numbers and the surface cannot crack
      for (j in 0...nz + 1)
        for (i in 0...nx + 1)
          {
            var x = (col0 + i / S) * CELL - half;
            var z = (row0 + j / S) * CELL - half;
            pos.push(x);
            pos.push(WildHeight.at(x, z));
            pos.push(z);
            WildHeight.pushNormal(nor, x, z);
            // uv off the FLAT world position, not off the displaced surface. arc length would be the
            // "correct" unwrap and it is the wrong call here: it needs a running integral along both
            // axes to stay continuous across chunk blocks, and at these slopes it would buy at most a
            // 2% stretch back on ground the camera sees at a steep angle anyway
            uv.push(x / WildStyle.GROUND_TILE);
            uv.push(z / WildStyle.GROUND_TILE);
            var t = tint(x, z);
            colr.push(t);
            colr.push(t);
            colr.push(t);
          }
      // two triangles per sub-quad, wound so the face normal comes out at +Y (the winding
      // render.sewer.SewerGeom.flat uses: increasing x, decreasing z)
      var idx = [];
      for (j in 0...nz)
        for (i in 0...nx)
          {
            var a = (j + 1) * (nx + 1) + i;
            var b = (j + 1) * (nx + 1) + i + 1;
            var c = j * (nx + 1) + i + 1;
            var d = j * (nx + 1) + i;
            idx.push(a);
            idx.push(b);
            idx.push(c);
            idx.push(a);
            idx.push(c);
            idx.push(d);
          }
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      // ANALYTIC, never computeVertexNormals: this is one mesh per chunk block, so a computed normal
      // on a block-edge vertex averages only the faces that block happens to hold and turns away from
      // its neighbour's answer — a lit seam down every chunk boundary. see WildHeight's header
      geo.setAttribute('normal', new Float32BufferAttribute(nor, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
      geo.setAttribute('color', new Float32BufferAttribute(colr, 3));
      geo.setIndex(idx);
      var mesh = new Mesh(geo, mat);
      // receives, never casts: it is the surface every shadow out here lands on, and the relief on it
      // is far too shallow to throw one — the measured peak slope is 0.164, i.e. 9.3 degrees, so the
      // moon would have to sit inside 9 degrees of the horizon before a hill shaded its own far side
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// the ground mottle at a world point, as a per-vertex grey multiplier.
//
// two out-of-phase sine octaves, NOT a hashed lattice. a hash evaluated at sub-quad resolution is
// white noise and reads as static; sines drift, and they are continuous by construction, so they
// cost nothing at a block boundary the way a lattice hash would (see render.sewer.SewerGeom.tint for
// the seam a per-face value produces).
//
// the FREQUENCIES are the part that had to be measured. they went in ten times lower, giving periods
// of 178 and 141 world units — 44 and 35 cells — and at that scale a +/-18% swing is not a mottle,
// it is a landmass: the frame read as a lit continent with a dark sea around it, and it took an A/B
// with the ground alone (row means 11.0 vs 14.5 across the frame) to confirm the ground was flat and
// evenly lit and only its VERTEX COLOUR was doing that. these give 17.8 and 14.1 units, i.e. 4.5 and
// 3.5 cells, which is the scale a dry patch actually has
  static function tint(x:Float, z:Float):Float
    {
      var v = Math.sin(x * 0.31 + z * 0.17) * 0.6 +
        Math.sin(x * 0.11 - z * 0.43) * 0.4;
      return 1.0 + v * WildStyle.TINT_AMP;
    }
}
