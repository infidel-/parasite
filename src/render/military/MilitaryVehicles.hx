package render.military;

import three.Three;
import citygen.CityConfig;
import game.AreaGame;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityDetail;
import render.facility.FacilityGround;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.world.VisionMask;

// a military base's hardware: the tank and the humvees in the motor pool, the helicopter on its pad
// and the plane in the hangar. each is a generated glb (art/models.json military/*) — a vehicle is
// carried by its outline, the facility car's reason — standing on the ORIGIN tile gen.military.
// MilitaryGen.vehicle stamped, centred on the footprint that origin names. the footprint is solid on
// the grid already, so this pass derives nothing but the pose
// one model the base parks
typedef VehicleKind = {
  // the origin tile that stands it
  tile:Int,
  // its footprint in cells, x then z
  size:Array<Int>,
  // the glb
  path:String,
  // the height it is drawn at
  h:Float,
  // its glb lies along local x, so it takes a quarter turn onto the footprint's long z
  turn:Bool,
}

class MilitaryVehicles
{
  static inline var CELL = CityConfig.CELL;

  // one row per model. the heights are fitted to the footprints off each glb's bbox (widest/height),
  // see their notes
  static var KINDS:Array<VehicleKind> = [
    {
      tile: Const.TILE_MIL_TANK,
      size: Const.MIL_TANK_SIZE,
      path: RenderConfig.MODELS.militaryTank,
      h: 4.9,
      turn: false,
    },
    {
      tile: Const.TILE_MIL_HUMVEE,
      size: Const.MIL_HUMVEE_SIZE,
      path: RenderConfig.MODELS.militaryHumvee,
      h: 3.8,
      turn: true,
    },
    {
      tile: Const.TILE_MIL_HELI,
      size: Const.MIL_HELI_SIZE,
      path: RenderConfig.MODELS.militaryHeli,
      h: 9.0,
      turn: false,
    },
    {
      tile: Const.TILE_MIL_PLANE,
      size: Const.MIL_PLANE_SIZE,
      path: RenderConfig.MODELS.militaryPlane,
      h: 7.5,
      turn: true,
    },
  ];

// every vehicle in the base, one instanced batch per model. runs before ContactMask.repaint, like
// MilitaryGeom: each one registers its footprint with the contact shadow
  public static function build(scene:Scene, m:Facility, area:AreaGame):Array<Models.InstancedProp>
    {
      var places:Array<Array<Models.PropPlace>> = [for (k in KINDS) []];
      for (row in 0...area.height)
        for (col in 0...area.width)
          {
            var t = area.getCellType(col, row);
            for (i in 0...KINDS.length)
              if (KINDS[i].tile == t)
                places[i].push(place(m, KINDS[i], col, row));
          }
      var out = [];
      for (i in 0...KINDS.length)
        {
          var prop = Models.instanced(scene, KINDS[i].path, places[i], KINDS[i].h, SOLID);
          if (places[i].length > 0)
            Models.get(KINDS[i].path, function(_) VisionMask.patchMesh(prop.mesh));
          out.push(prop);
        }
      return out;
    }

// the glbs the base draws, for render.facility.FacilityWarm's extra rows
  public static function warmProps():Array<{ path:String, h:Float }>
    {
      return [for (k in KINDS) {
        path: k.path,
        h: k.h,
      }];
    }

// one vehicle's pose on its footprint, and its contact shadow
  static function place(m:Facility, k:VehicleKind, col:Int, row:Int):Models.PropPlace
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      var x1 = x0 + k.size[0] * CELL;
      var z1 = z0 + k.size[1] * CELL;
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: 1,
        alongX: true,
        rect: {
          x0: x0,
          x1: x1,
          z0: z0,
          z1: z1,
        },
        h: k.h,
      });
      // a half turn on half of them, which way it is parked being the only variety one model has
      var h = FacilityModel.mix((col * 68171) ^ (row * 3010349));
      return {
        x: (x0 + x1) / 2,
        z: (z0 + z1) / 2,
        yaw: (k.turn ? Math.PI / 2 : 0.0) + (h % 2) * Math.PI,
        y: FacilityGround.surfY(m.surf[row][col]),
      };
    }
}
