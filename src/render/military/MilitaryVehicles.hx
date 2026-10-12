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
    // the plane as big as the vault lets it be: at 7.5 it was a 12 m light twin beside the crew ("plane
    // scale looks a little wrong"), and filling its footprint's span at 9.6 put the T-tail through the
    // roof. Its fin stands two and a half cells off the middle of the floor, under the arch's fall, and
    // 8.6 clears it by 0.31 in the shallowest vault a base deals (16x11: an arch over 42 rising 3.78)
    {
      tile: Const.TILE_MIL_PLANE,
      size: Const.MIL_PLANE_SIZE,
      path: RenderConfig.MODELS.militaryPlane,
      h: 8.6,
      turn: true,
    },
  ];

  // what of the plane comes down near the floor, world units off its footprint's centre nose north,
  // [ x0, x1, z0, z1 ], measured off the glb at its h: the fuselage and the two main wheels. Its
  // contact shadow is these and not the footprint, which laid a black block 8x7 cells under the wings
  static var PLANE_LOW = [
    [ -1.45, 1.45, -10.75, 8.7 ],
    [ -3.7, -2.7, -1.5, -0.4 ],
    [ 2.7, 3.7, -1.5, -0.4 ],
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
                places[i].push(place(m, area, KINDS[i], col, row));
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
  static function place(m:Facility, area:AreaGame, k:VehicleKind, col:Int, row:Int):Models.PropPlace
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      var x1 = x0 + k.size[0] * CELL;
      var z1 = z0 + k.size[1] * CELL;
      // the plane faces the way gen.military.MilitaryGen.plane stamped it, and shadows its own parts
      if (k.tile == Const.TILE_MIL_PLANE)
        {
          var s = (planeNorth(area, col, row) ? 1 : -1);
          var cx = (x0 + x1) / 2;
          var cz = (z0 + z1) / 2;
          for (p in PLANE_LOW)
            FacilityDetail.ground(m, {
              col: col,
              row: row,
              len: 1,
              alongX: true,
              rect: {
                x0: cx + Math.min(p[0] * s, p[1] * s),
                x1: cx + Math.max(p[0] * s, p[1] * s),
                z0: cz + Math.min(p[2] * s, p[3] * s),
                z1: cz + Math.max(p[2] * s, p[3] * s),
              },
              h: 2.0,
            });
          return {
            x: cx,
            z: cz,
            yaw: Math.PI / 2 + (s > 0 ? 0.0 : Math.PI),
            y: FacilityGround.surfY(m.surf[row][col]),
          };
        }
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

// which way the plane named from this origin faces: its stamp is Const.MIL_PLANE_MASK nose north, or
// that turned a half. Read off the first cell the two disagree on; a save from before the outline
// has the whole footprint solid, and reads as north
  static function planeNorth(area:AreaGame, col:Int, row:Int):Bool
    {
      var mask = Const.MIL_PLANE_MASK;
      for (j in 0...mask.length)
        for (i in 0...mask[j].length)
          if (mask[j].charAt(i) == 'x' &&
              mask[mask.length - 1 - j].charAt(mask[j].length - 1 - i) != 'x')
            return area.getCellType(col + i, row + j) == Const.TILE_MIL_VEHICLE;
      return true;
    }
}
