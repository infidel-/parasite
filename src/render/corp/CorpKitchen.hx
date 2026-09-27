package render.corp;

import citygen.CityConfig;
import render.Models;
import render.facility.ClutterSlot;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;

// what render.corp.CorpProps batches for the staff kitchen, one list per glb
typedef KitchenPlaces = {
  var tables:Array<Models.PropPlace>;
  var chairs:Array<Models.PropPlace>;
  var counters:Array<Models.PropPlace>;
  var sinks:Array<Models.PropPlace>;
  var cabs:Array<Models.PropPlace>;
  var fridges:Array<Models.PropPlace>;
  var vendings:Array<Models.PropPlace>;
  var microwaves:Array<Models.PropPlace>;
  var coffees:Array<Models.PropPlace>;
  var kettles:Array<Models.PropPlace>;
  var toasters:Array<Models.PropPlace>;
};

// one top the kitchen's clutter lies on — a dining table's or a fridge's — in world units, with the
// boxes already standing on it
typedef KitchenTop = {
  var x:Float;
  var z:Float;
  // half extents along world x and z
  var hw:Float;
  var hd:Float;
  // the top's height
  var y:Float;
  // the cell the scatter's roll is seeded off
  var col:Int;
  var row:Int;
  // true for a dining table, false for a fridge's top
  var table:Bool;
  var spots:Array<ClutterSlot>;
};

// one counter cell: where its module's centre stands and the hand its wall is on (-1 for none)
typedef KitchenCounter = {
  var col:Int;
  var row:Int;
  var dir:Int;
  var x:Float;
  var z:Float;
  // the cell carries the tap, so the module is the sink
  var sink:Bool;
};

// one tall piece standing on the kitchen floor against its wall: its cell, the hand its wall is on
// and its centre
typedef KitchenStand = {
  var col:Int;
  var row:Int;
  var dir:Int;
  var x:Float;
  var z:Float;
};

// one appliance standing on a counter
typedef KitchenAppliance = {
  var list:Int;
  var x:Float;
  var z:Float;
  var yaw:Float;
  // its drawn half extents along world x and z
  var hw:Float;
  var hd:Float;
};

// THE STAFF KITCHEN'S FURNITURE, off the generator's own cells — render.corp.CorpExec's shape.
//
// gen.corp.CorpKitchen lays the prep counter as 1x1 worktop tiles along a wall with the tap and the
// appliances dealt onto them and the fridge on the floor at the run's corner end, the dining tables
// as 2x2 blocks with chairs on two of their sides, and the snack corner's vending machine on the
// floor by a door. This stands a glb on every one of them, each turned off a NEIGHBOUR rather than
// stored: a counter, a fridge and a vending machine face away from their wall, a chair faces its
// table, a table runs its long sides toward its chairs.
//
// A COUNTER IS A 4 x 1.32 UNIT AGAINST ITS WALL, not the 3.76 plinth the whole cell used to be:
// render.corp.CorpFurniture.worktop emitted every kitchen worktop as a closed box of counter art,
// the 2x2 dining tables included. The rest of the cell is floor you can see and cannot walk on,
// which is what a cooler or a cabinet already is on this plate.
//
// A PURE FUNCTION OF THE GRID AND THE AREA'S OBJECTS, so render.corp.CorpClutter can ask where the
// tables and the fridges stand without having run after render.corp.CorpProps. With no area it
// places nothing.
class CorpKitchen
{
  static inline var CELL = CityConfig.CELL;

  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // which of KitchenPlaces' appliance lists an appliance goes on
  static inline var L_MICROWAVE = 0;
  static inline var L_COFFEE = 1;
  static inline var L_KETTLE = 2;
  static inline var L_TOASTER = 3;

// is this a kitchen worktop cell, which a glb stands on instead of render.corp.CorpFurniture
// emitting a box?
  public static inline function cell(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        m.table[row][col] &&
        m.surf[row][col] == Surf.KITCHEN;
    }

// every glb the kitchen stands, into `out`, with the contact under each
  public static function place(m:Facility, area:game.AreaGame, out:KitchenPlaces):Void
    {
      if (area == null)
        return;
      var cs = counters(m, area);
      for (c in cs)
        {
          var yaw = (c.dir < 0 ? 0.0 : Math.atan2(DC[c.dir ^ 1], DR[c.dir ^ 1]));
          (c.sink ? out.sinks : out.counters).push({
            x: c.x,
            z: c.z,
            yaw: yaw,
          });
          // A CABINET OVER EVERY COUNTER CELL WITH MASONRY BEHIND IT but the sink, where the
          // splashback is left open
          if (c.sink ||
              c.dir < 0 ||
              !FacilityModel.isSolidWall(m, c.col + DC[c.dir], c.row + DR[c.dir]))
            continue;
          var p = against(m, c.col, c.row, c.dir, CorpStyle.CAB_D);
          out.cabs.push({
            x: p.x,
            z: p.z,
            yaw: yaw,
            y: CorpStyle.CAB_Y,
          });
        }
      runs(m, cs);
      // the fridge and the vending machine, backed onto their wall like the counter
      tall(m, area, CorpDeco.K_FRIDGE, CorpStyle.FRIDGE_W, CorpStyle.FRIDGE_D, CorpStyle.FRIDGE_H,
        out.fridges);
      tall(m, area, CorpDeco.K_VENDING, CorpStyle.VENDING_W, CorpStyle.VENDING_D,
        CorpStyle.VENDING_H, out.vendings);
      // the dining tables, each turned so its long sides face the sides its chairs are on
      var chairs = cellSet(m, kitchenCells(m, area, CorpDeco.K_CHAIR));
      for (t in tables(m, area, chairs))
        {
          out.tables.push({
            x: t.x,
            z: t.z,
            yaw: t.yaw,
          });
          FacilityDetail.ground(m, {
            col: t.col,
            row: t.row,
            len: 2,
            alongX: true,
            rect: {
              x0: t.x - t.hw,
              x1: t.x + t.hw,
              z0: t.z - t.hd,
              z1: t.z + t.hd,
            },
            h: CorpStyle.KITCHEN_TABLE_H,
          });
        }
      // the chairs, pulled in to the table they face and turned a little off square. A chair in the
      // row BETWEEN two tables faces one by the parity of its cell, so the shared row seats both
      for (c in kitchenCells(m, area, CorpDeco.K_CHAIR))
        {
          var ks = [for (d in 0...4)
            if (cell(m, c.col + DC[d], c.row + DR[d]) &&
                dining(area, c.col + DC[d], c.row + DR[d]))
              d];
          if (ks.length == 0)
            continue;
          var k = ks[(c.col + c.row) % ks.length];
          var hash = FacilityModel.mix((c.col * 374761393) ^ (c.row * 668265263));
          var w = CityConfig.cellToWorld(c.col, c.row);
          var x = w.x + DC[k] * CorpStyle.KITCHEN_CHAIR_IN;
          var z = w.z + DR[k] * CorpStyle.KITCHEN_CHAIR_IN;
          out.chairs.push({
            x: x,
            z: z,
            yaw: Math.atan2(DC[k], DR[k]) +
              ((hash % 1000) / 1000 * 2 - 1) * CorpStyle.KITCHEN_CHAIR_JITTER,
          });
          var hw = CorpStyle.KITCHEN_CHAIR_W / 2;
          FacilityDetail.ground(m, {
            col: c.col,
            row: c.row,
            len: 1,
            alongX: true,
            rect: {
              x0: x - hw,
              x1: x + hw,
              z0: z - hw,
              z1: z + hw,
            },
            h: CorpStyle.KITCHEN_CHAIR_H,
          });
        }
      // and what stands on the counters, each in the round pool of its own shadow on the top
      var lists = [ out.microwaves, out.coffees, out.kettles, out.toasters ];
      for (a in appliances(m, area, cs))
        {
          lists[a.list].push({
            x: a.x,
            z: a.z,
            yaw: a.yaw,
            y: CorpStyle.COUNTER_H,
          });
          var c = CityConfig.worldToCell(a.x, a.z);
          var w = CityConfig.cellToWorld(c.col, c.row);
          FacilityDetail.deck({
            cx: a.x,
            cz: a.z,
            hw: a.hw,
            hd: a.hd,
            yaw: 0.0,
            y: CorpStyle.COUNTER_H,
            plate: {
              x0: w.x - CELL / 2,
              x1: w.x + CELL / 2,
              z0: w.z - CELL / 2,
              z1: w.z + CELL / 2,
            },
          });
        }
    }

// every top the kitchen's clutter may lie on: each dining table's, and each fridge's
  public static function tops(m:Facility, area:game.AreaGame):Array<KitchenTop>
    {
      var out:Array<KitchenTop> = [];
      if (area == null)
        return out;
      for (t in tables(m, area, cellSet(m, kitchenCells(m, area, CorpDeco.K_CHAIR))))
        out.push({
          x: t.x,
          z: t.z,
          hw: t.hw,
          hd: t.hd,
          y: CorpStyle.KITCHEN_TABLE_H,
          col: t.col,
          row: t.row,
          table: true,
          spots: [],
        });
      for (f in fridges(m, area))
        out.push({
          x: f.x,
          z: f.z,
          hw: (f.dir < 2 ? CorpStyle.FRIDGE_W : CorpStyle.FRIDGE_D) / 2,
          hd: (f.dir < 2 ? CorpStyle.FRIDGE_D : CorpStyle.FRIDGE_W) / 2,
          y: CorpStyle.FRIDGE_H,
          col: f.col,
          row: f.row,
          table: false,
          spots: [],
        });
      return out;
    }

// every fridge, backed onto its wall
  public static function fridges(m:Facility, area:game.AreaGame):Array<KitchenStand>
    {
      return (area == null ? [] : standing(m, area, CorpDeco.K_FRIDGE, CorpStyle.FRIDGE_D));
    }

// the hand a floor piece on a kitchen cell backs onto — the cooler's, which render.corp.CorpProps
// stands: in the snack corner's CORNER both hands are masonry and only the run says which is its
  public static function hand(m:Facility, area:game.AreaGame, col:Int, row:Int):Int
    {
      return runHand(m, col, row, runSet(m, area));
    }

// is this kitchen worktop cell part of a DINING TABLE rather than the counter? the tile says: the
// generator lays a table as Const.LIGHT_TABLE_WOOD1_2X2 and a counter as the 1x1 tile
  static function dining(area:game.AreaGame, col:Int, row:Int):Bool
    {
      var t = area.getCellType(col, row);
      for (r in Const.LIGHT_TABLE_WOOD1_2X2)
        for (id in r)
          if (t == id)
            return true;
      return false;
    }

// every counter cell, where its module stands and the wall it backs onto. Masonry first, the way
// every wall-hugging family here asks; an old save's counter against glazing takes the glass, and
// an old galley in the middle of the room stands on its cell's centre
  static function counters(m:Facility, area:game.AreaGame):Array<KitchenCounter>
    {
      var taps = cellSet(m, kitchenCells(m, area, CorpDeco.K_TAP));
      var run = runSet(m, area);
      var out = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!cell(m, col, row) ||
                dining(area, col, row))
              continue;
            var dir = runHand(m, col, row, run);
            var p = (dir < 0 ? CityConfig.cellToWorld(col, row) :
              against(m, col, row, dir, CorpStyle.COUNTER_D));
            out.push({
              col: col,
              row: row,
              dir: dir,
              x: p.x,
              z: p.z,
              sink: taps.exists(key(m, col, row)),
            });
          }
      return out;
    }

// the contact under the counters, ONCE PER RUN: cells side by side along the same wall make one
// footprint, so their halos do not compound down the wall
  static function runs(m:Facility, cs:Array<KitchenCounter>):Void
    {
      var at = new Map<Int, KitchenCounter>();
      for (c in cs)
        at.set(key(m, c.col, c.row), c);
      for (c in cs)
        {
          var alongX = (c.dir < 2);
          var sc = (alongX ? 1 : 0), sr = (alongX ? 0 : 1);
          // a run is taken from its first cell only
          var prev = at.get(key(m, c.col - sc, c.row - sr));
          if (prev != null &&
              prev.dir == c.dir)
            continue;
          var len = 1;
          while (true)
            {
              var next = at.get(key(m, c.col + sc * len, c.row + sr * len));
              if (next == null ||
                  next.dir != c.dir)
                break;
              len++;
            }
          var ha = CELL / 2, hc = CorpStyle.COUNTER_D / 2;
          var ex = c.x + sc * (len - 1) * CELL, ez = c.z + sr * (len - 1) * CELL;
          FacilityDetail.ground(m, {
            col: c.col,
            row: c.row,
            len: len,
            alongX: alongX,
            rect: {
              x0: c.x - (alongX ? ha : hc),
              x1: ex + (alongX ? ha : hc),
              z0: c.z - (alongX ? hc : ha),
              z1: ez + (alongX ? hc : ha),
            },
            h: CorpStyle.COUNTER_H,
          });
        }
    }

// one tall family (the fridge, the vending machine) on its dealt cells, backed onto the wall
  static function tall(m:Facility, area:game.AreaGame, kind:Int, w:Float, d:Float, h:Float,
      list:Array<Models.PropPlace>):Void
    {
      for (p in standing(m, area, kind, d))
        {
          list.push({
            x: p.x,
            z: p.z,
            yaw: Math.atan2(DC[p.dir ^ 1], DR[p.dir ^ 1]),
          });
          var hw = (p.dir < 2 ? w : d) / 2;
          var hd = (p.dir < 2 ? d : w) / 2;
          FacilityDetail.ground(m, {
            col: p.col,
            row: p.row,
            len: 1,
            alongX: true,
            rect: {
              x0: p.x - hw,
              x1: p.x + hw,
              z0: p.z - hd,
              z1: p.z + hd,
            },
            h: h,
          });
        }
    }

// where each of one kind's dealt cells stands a piece `d` deep, and the wall it backs onto
  static function standing(m:Facility, area:game.AreaGame, kind:Int, d:Float):Array<KitchenStand>
    {
      var run = runSet(m, area);
      var out = [];
      for (c in CorpDeco.cells(area, kind))
        {
          var dir = runHand(m, c.col, c.row, run);
          if (dir < 0)
            continue;
          var p = against(m, c.col, c.row, dir, d);
          out.push({
            col: c.col,
            row: c.row,
            dir: dir,
            x: p.x,
            z: p.z,
          });
        }
      return out;
    }

// every dining table: the top-left cell of each 2x2 block, its centre, and its turn — the model's
// long side runs along x, so a table whose chairs are on its west and east hands takes a quarter
  static function tables(m:Facility, area:game.AreaGame, chairs:Map<Int, Bool>):Array<{ col:Int,
      row:Int, x:Float, z:Float, yaw:Float, hw:Float, hd:Float }>
    {
      var out = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!cell(m, col, row) ||
                area.getCellType(col, row) != Const.LIGHT_TABLE_WOOD1_2X2[0][0])
              continue;
            var ns = 0, we = 0;
            for (i in 0...2)
              {
                if (chairs.exists(key(m, col + i, row - 1)))
                  ns++;
                if (chairs.exists(key(m, col + i, row + 2)))
                  ns++;
                if (chairs.exists(key(m, col - 1, row + i)))
                  we++;
                if (chairs.exists(key(m, col + 2, row + i)))
                  we++;
              }
            var turned = (we > ns);
            var c = CityConfig.cellToWorld(col + 0.5, row + 0.5);
            out.push({
              col: col,
              row: row,
              x: c.x,
              z: c.z,
              yaw: (turned ? Math.PI / 2 : 0.0),
              hw: (turned ? CorpStyle.KITCHEN_TABLE_D : CorpStyle.KITCHEN_TABLE_W) / 2,
              hd: (turned ? CorpStyle.KITCHEN_TABLE_W : CorpStyle.KITCHEN_TABLE_D) / 2,
            });
          }
      return out;
    }

// the appliances dealt onto the counter, each at the back of its cell's top facing the room, slid
// along the counter by the cell's hash. A kettle cell stands a TOASTER on half of them by the same
// hash: the generator deals one group for the two
  static function appliances(m:Facility, area:game.AreaGame,
      cs:Array<KitchenCounter>):Array<KitchenAppliance>
    {
      var at = new Map<Int, KitchenCounter>();
      for (c in cs)
        at.set(key(m, c.col, c.row), c);
      var out = [];
      for (kind in [ CorpDeco.K_MICROWAVE, CorpDeco.K_COFFEE, CorpDeco.K_KETTLE ])
        for (cc in CorpDeco.cells(area, kind))
          {
            var c = at.get(key(m, cc.col, cc.row));
            if (c == null ||
                c.sink)
              continue;
            var hash = FacilityModel.mix((c.col * 374761393) ^ (c.row * 668265263));
            var list = (kind == CorpDeco.K_MICROWAVE ? L_MICROWAVE :
              (kind == CorpDeco.K_COFFEE ? L_COFFEE : (hash % 2 == 0 ? L_KETTLE : L_TOASTER)));
            var dims = [ CorpStyle.MICROWAVE, CorpStyle.COFFEE, CorpStyle.KETTLE,
              CorpStyle.TOASTER ][list];
            var w = dims[1] * CorpStyle.APPLIANCE_SCALE;
            var d = dims[2] * CorpStyle.APPLIANCE_SCALE;
            // along the counter anywhere its width leaves room for, and back against the wall
            var dir = (c.dir < 0 ? 1 : c.dir);
            var sc = (dir < 2 ? 1 : 0), sr = (dir < 2 ? 0 : 1);
            var span = CELL / 2 - w / 2 - CorpStyle.CLUTTER_INSET;
            var along = ((((hash >>> 8) % 1000) / 1000) * 2 - 1) * span;
            var back = (c.dir < 0 ? 0.0 : CorpStyle.COUNTER_D / 2 - d / 2 - CorpStyle.APPLIANCE_BACK);
            out.push({
              list: list,
              x: c.x + sc * along + DC[dir] * back,
              z: c.z + sr * along + DR[dir] * back,
              yaw: Math.atan2(DC[dir ^ 1], DR[dir ^ 1]),
              hw: (dir < 2 ? w : d) / 2,
              hd: (dir < 2 ? d : w) / 2,
            });
          }
      return out;
    }

// the centre of a piece `d` deep standing with its back PROP_GAP off the face of the wall on hand
// `dir` — render.corp.CorpDeco.bins' arithmetic, which reads glazing and masonry alike
  static function against(m:Facility, col:Int, row:Int, dir:Int, d:Float):{ x:Float, z:Float }
    {
      var w = CityConfig.cellToWorld(col, row);
      var off = CELL - FacilityGeom.wallFace(m, col + DC[dir], row + DR[dir], dir ^ 1) - d / 2 -
        CorpStyle.PROP_GAP;
      return {
        x: w.x + DC[dir] * off,
        z: w.z + DR[dir] * off,
      };
    }

// every cell of the kitchen's two wall runs — the counter, the fridge, and the snack corner's
// vending machine, cooler and bin — keyed by `key`
  static function runSet(m:Facility, area:game.AreaGame):Map<Int, Bool>
    {
      var out = new Map<Int, Bool>();
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (cell(m, col, row) &&
              !dining(area, col, row))
            out.set(key(m, col, row), true);
      for (kind in [ CorpDeco.K_FRIDGE, CorpDeco.K_VENDING, CorpDeco.K_COOLER, CorpDeco.K_BIN ])
        for (c in kitchenCells(m, area, kind))
          out.set(key(m, c.col, c.row), true);
      return out;
    }

// the hand a piece of a wall RUN backs onto. IN A CORNER BOTH HANDS ARE MASONRY, and `wallHand`
// takes the first in DC/DR's order: the fridge closing a run down the west wall stood with its back
// to the NORTH one, square across its own counter. A neighbour in the run says which axis the run
// lies on, and the back is across it
  static function runHand(m:Facility, col:Int, row:Int, run:Map<Int, Bool>):Int
    {
      var alongX = run.exists(key(m, col - 1, row)) || run.exists(key(m, col + 1, row));
      var alongZ = run.exists(key(m, col, row - 1)) || run.exists(key(m, col, row + 1));
      if (alongX != alongZ)
        for (d in (alongX ? [ 0, 1 ] : [ 2, 3 ]))
          if (FacilityModel.isWall(m, col + DC[d], row + DR[d]))
            return d;
      return wallHand(m, col, row);
    }

// the hand a kitchen piece backs onto: masonry that runs on past the cell, else any wall at all
  static function wallHand(m:Facility, col:Int, row:Int):Int
    {
      var dir = CorpDeco.backHandOf(m, col, row);
      if (dir >= 0)
        return dir;
      for (d in 0...4)
        if (FacilityModel.isWall(m, col + DC[d], row + DR[d]))
          return d;
      return -1;
    }

// one kind's dealt cells that stand on the kitchen's floor
  static function kitchenCells(m:Facility, area:game.AreaGame, kind:Int):Array<{ col:Int, row:Int }>
    {
      return [for (c in CorpDeco.cells(area, kind))
        if (FacilityModel.inside(m, c.col, c.row) &&
            m.surf[c.row][c.col] == Surf.KITCHEN)
          c];
    }

// a list of cells as a set keyed by `key`
  static function cellSet(m:Facility, cells:Array<{ col:Int, row:Int }>):Map<Int, Bool>
    {
      var out = new Map<Int, Bool>();
      for (c in cells)
        out.set(key(m, c.col, c.row), true);
      return out;
    }

// one cell as a map key
  static inline function key(m:Facility, col:Int, row:Int):Int
    {
      return row * m.w + col;
    }
}
