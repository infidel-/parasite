package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// one greenery model and which tile id plants it
typedef GreenProp = {
  // the tile the generator wrote (Const.TILE_TREE1..+3 and Const.TILE_BUSH)
  tile:Int,
  // RenderConfig.MODELS entry
  path:String,
  // world height, and with it the width: render.Models.instanced scales by HEIGHT alone
  h:Float,
  // how far off its cell centre a plant may sit, as a fraction of a cell
  jitter:Float,
};

// the facility's OUTDOORS: the four ground surfaces and the park's trees and bushes.
//
// one merged mesh per surface type rather than per cell, exactly as render.world.Ground does for a
// city street, and world-aligned UVs on both axes so nothing is ever stretched and abutting cells
// share one continuous grid. flat at y = 0 — a facility has no relief and, in this phase, no kerb
class FacilityGround
{
  static inline var CELL = CityConfig.CELL;

  // the park is dressed with the wilderness's own plants: same night, same style, same four trees
  // the tile ids already distinguish. mapped ONE TO ONE off the tile, so what the generator wrote is
  // what grows — the rule render.wild.WildModel settled on after the wilderness collapsed four ids
  // onto two models
  public static final GREEN:Array<GreenProp> = [
    {
      tile: Const.TILE_TREE1,
      path: RenderConfig.MODELS.wildTreeConifer,
      h: 7.5,
      jitter: 0.20,
    },
    {
      tile: Const.TILE_TREE1 + 1,
      path: RenderConfig.MODELS.wildTreeBroadleaf,
      h: 6.5,
      jitter: 0.22,
    },
    {
      tile: Const.TILE_TREE1 + 2,
      path: RenderConfig.MODELS.wildTreeBroadleafFull,
      h: 9.5,
      jitter: 0.22,
    },
    {
      tile: Const.TILE_TREE1 + 3,
      path: RenderConfig.MODELS.wildTreeDead,
      h: 5.6,
      jitter: 0.26,
    },
    {
      tile: Const.TILE_BUSH,
      path: RenderConfig.MODELS.wildBushLow,
      h: 1.1,
      jitter: 0.28,
    },
  ];

// the ground surfaces
  public static function build(scene:Scene, m:Facility):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var road = MeshBufTools.make();
      var walkway = MeshBufTools.make();
      var lot = MeshBufTools.make();
      var grass = MeshBufTools.make();
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var b = switch (m.surf[row][col])
              {
                case Surf.ROAD: road;
                case Surf.WALKWAY: walkway;
                case Surf.LOT: lot;
                case Surf.GRASS: grass;
                default: null;
              };
            if (b == null)
              continue;
            var x0 = col * CELL - half, x1 = x0 + CELL;
            var z0 = row * CELL - half, z1 = z0 + CELL;
            var t = FacilityStyle.GROUND_TILE;
            MeshBufTools.quad(b, [x0, 0, z1], [x1, 0, z1], [x1, 0, z0], [x0, 0, z0],
              [x0 / t, z1 / t, x1 / t, z1 / t, x1 / t, z0 / t, x0 / t, z0 / t]);
          }
      add(scene, road, FacilityStyle.GROUND_ROAD);
      add(scene, walkway, FacilityStyle.GROUND_WALKWAY);
      add(scene, lot, FacilityStyle.GROUND_LOT);
      add(scene, grass, FacilityStyle.GROUND_GRASS);
    }

// the park's trees and bushes, one instanced batch per model. the tiles are already unwalkable, so
// this is not decoration: a green cell with nothing drawn on it is a wall the player cannot see
  public static function green(scene:Scene, m:Facility, area:game.AreaGame):Array<Models.InstancedProp>
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var places = [for (_ in GREEN) new Array<Models.PropPlace>()];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.GRASS)
              continue;
            var t = area.getCellType(col, row);
            for (i in 0...GREEN.length)
              {
                if (GREEN[i].tile != t)
                  continue;
                // three rolls off one mixed hash, with multipliers of their own so a plant's offset
                // does not correlate with its turn
                var hx = FacilityModel.mix((col * 30011) ^ (row * 50021));
                var hz = FacilityModel.mix((col * 19349663) ^ (row * 83492791));
                var hy = FacilityModel.mix((col * 24036583) ^ (row * 32582657));
                var j = GREEN[i].jitter;
                places[i].push({
                  x: (col + 0.5 + ((hx % 2001) / 1000.0 - 1.0) * j) * CELL - half,
                  z: (row + 0.5 + ((hz % 2001) / 1000.0 - 1.0) * j) * CELL - half,
                  yaw: (hy % 6283) / 1000.0,
                });
              }
          }
      var props = [];
      for (i in 0...GREEN.length)
        {
          var p = Models.instanced(scene, GREEN[i].path, places[i], GREEN[i].h, SOLID);
          props.push(p);
          // the mask has to be applied behind the loader callback, because the mesh does not exist
          // until the glb resolves — and only for a batch that actually placed something, or an
          // empty batch's material is patched and warmed for nothing
          if (places[i].length > 0)
            Models.get(GREEN[i].path, function(_) VisionMask.patchMesh(p.mesh));
        }
      return props;
    }

// merge one surface buffer into a lit mesh
  static function add(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      var mesh = new Mesh(geo, VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'ground', 1),
        side: THREE.FrontSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
