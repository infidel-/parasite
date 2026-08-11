package render.sewer;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.sewer.SewerModel.Sewer;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// static tunnel SHELL from a SewerModel: walkway floor, inward-facing walls and the flat wall tops
// the overhead camera looks down on. everything merges into ONE mesh per texture — six draw calls
// for a whole level (floor, ledge, and one per wall variation). nothing here fades (there is no sewer occlusion pass), which is
// exactly why it can all be welded like this; see docs/3d-render.md on the Occlusion constraint.
// the dressing that sits ON the shell (decals, grime, contact shadows) lives in SewerDetail
class SewerGeom
{
  static inline var CELL = CityConfig.CELL;

// build every tunnel surface into the scene
  public static function build(scene:Scene, m:Sewer):Void
    {
      var half = (CityConfig.GRID * CELL) / 2; // the shared cell->world origin (see CityConfig.cellToWorld)
      var floor = MeshBufTools.make();
      var ledge = MeshBufTools.make();
      // one buffer per wall variation: every face picks its own, so a run of wall is not one flat
      // repeat. merged per variation, so the whole level still costs one draw call each
      var walls = [for (_ in SewerStyle.WALLS) MeshBufTools.make()];

      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var x0 = col * CELL - half, x1 = x0 + CELL;
            var z0 = row * CELL - half, z1 = z0 + CELL;
            // solid cell: cap it, so the camera looks down on a ledge and not on a paper-thin wall
            // edge. EVERY solid cell, not just the shell orthogonally touching floor — the caps
            // form one continuous plateau at WALL_H, so an interior or diagonal-only solid cell
            // left uncapped is a hole straight through the plateau to the background. 2 tris a
            // cell into an already-merged mesh, so no extra draw call
            if (!m.floor[row][col])
              {
                flat(ledge, x0, x1, z0, z1, SewerStyle.WALL_H, SewerStyle.LEDGE_TILE);
                continue;
              }
            // floor: one continuous walkway. the corridor centreline used to run a sludge tile
            // instead of concrete — see SewerModel on why that grid is gone with it
            flat(floor, x0, x1, z0, z1, 0.0, SewerStyle.FLOOR_TILE);
            // walls on every edge facing a solid neighbour, wound to face into this cell. the
            // variation is picked PER FACE off its own (cell, dir) hash — mixed, or the area border
            // combs (see SewerModel.mix), and with multipliers of its own so a face's texture does
            // not correlate with the decal SewerDetail rolls for the same face
            inline function buf(dir:Int):MeshBuf
              return walls[SewerModel.mix((col * 30011) ^ (row * 50021) ^ (dir * 70001)) % walls.length];
            if (!SewerModel.isFloor(m, col, row - 1))
              side(buf(0), 0, x0, x1, z0, z1);
            if (!SewerModel.isFloor(m, col, row + 1))
              side(buf(1), 1, x0, x1, z0, z1);
            if (!SewerModel.isFloor(m, col - 1, row))
              side(buf(2), 2, x0, x1, z0, z1);
            if (!SewerModel.isFloor(m, col + 1, row))
              side(buf(3), 3, x0, x1, z0, z1);
          }

      add(scene, floor, SewerStyle.FLOOR, true, false);
      add(scene, ledge, SewerStyle.LEDGE, true, false);
      for (i in 0...walls.length)
        add(scene, walls[i], SewerStyle.WALLS[i], true, true);
      // dressing on top of the shell: SewerDetail owns the wall face, SewerGround the two horizontal
      // surfaces. called from HERE, not from SewerArea, so that View.warmup — which compiles a
      // throwaway SewerModel.demo() through this same function — warms the decal, grime, rim and
      // contact-shadow materials too, with no second wiring point to forget
      SewerDetail.build(scene, m);
      SewerGround.build(scene, m);
    }

// one horizontal cell quad at height y, world-aligned UVs (never stretched)
  static function flat(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, t:Float):Void
    {
      MeshBufTools.quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
        [x0 / t, z1 / t, x1 / t, z1 / t, x1 / t, z0 / t, x0 / t, z0 / t]);
    }

// one vertical wall quad on a cell edge, facing INTO the cell.
// dir: 0 = north edge (faces +z), 1 = south (-z), 2 = west (+x), 3 = east (-x)
  static function side(b:MeshBuf, dir:Int, x0:Float, x1:Float, z0:Float, z1:Float):Void
    {
      var H = SewerStyle.WALL_H;
      var t = SewerStyle.WALL_TILE;
      switch (dir)
        {
          case 0:
            MeshBufTools.quad(b, [x0, 0, z0], [x1, 0, z0], [x1, H, z0], [x0, H, z0],
              [x0 / t, 0, x1 / t, 0, x1 / t, H / t, x0 / t, H / t]);
          case 1:
            MeshBufTools.quad(b, [x1, 0, z1], [x0, 0, z1], [x0, H, z1], [x1, H, z1],
              [x1 / t, 0, x0 / t, 0, x0 / t, H / t, x1 / t, H / t]);
          case 2:
            MeshBufTools.quad(b, [x0, 0, z1], [x0, 0, z0], [x0, H, z0], [x0, H, z1],
              [z1 / t, 0, z0 / t, 0, z0 / t, H / t, z1 / t, H / t]);
          default:
            MeshBufTools.quad(b, [x1, 0, z0], [x1, 0, z1], [x1, H, z1], [x1, H, z0],
              [z0 / t, 0, z1 / t, 0, z1 / t, H / t, z0 / t, H / t]);
        }
    }

// turn one buffer into a single lit mesh. Lambert, not Standard: measured -42% GPU on the city
// surfaces for no visual loss (docs/3d-render.md).
// everything here is FrontSide: walls are wound inward and the horizontals' normals come out at +Y
// with the camera always above them, so a back face is never seen and rasterizing one is pure waste.
// the floor and the ledge used to get DoubleSide as a side effect of not casting shadows — two
// unrelated decisions on one flag, which is also how it stayed unnoticed
  static function add(scene:Scene, b:MeshBuf, tex:String, recv:Bool, casts:Bool):Void
    {
      if (b.idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      var mesh = new Mesh(geo, new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: THREE.FrontSide,
      }));
      mesh.receiveShadow = recv;
      mesh.castShadow = casts;
      scene.add(mesh);
    }
}
