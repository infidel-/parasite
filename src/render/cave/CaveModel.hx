package render.cave;

import game.AreaGame;
import tiles.Sewers;
import render.sewer.SewerModel;
import render.sewer.SewerModel.Sewer;

// what the 3D cave builder needs, derived from the habitat's SAVED cell grid: the floor, the
// chambers and a light at each cave mouth. the same record the tunnels use (render.sewer.SewerModel's
// Sewer) — the cave keeps the sewer tile ids (gen.SewerShell), so the grid reads the same — but no
// corridor-node lamps: there are no manholes in a mountain
class CaveModel
{
// build the model from a cave habitat's saved cells + generator chambers
  public static function fromArea(area:AreaGame):Sewer
    {
      var m = blank(area.width, area.height);
      for (y in 0...area.height)
        for (x in 0...area.width)
          m.floor[y][x] = (area.getCellType(x, y) == Sewers.TILE_FLOOR);
      if (area.generatorInfo != null &&
          area.generatorInfo.rooms != null)
        for (r in area.generatorInfo.rooms)
          for (y in r.y1...r.y2 + 1)
            for (x in r.x1...r.x2 + 1)
              if (x < m.w &&
                  y < m.h)
                m.room[y][x] = true;
      for (o in area.getObjects())
        if (o.type == 'habitat_exit' &&
            SewerModel.isFloor(m, o.x, o.y))
          m.lamps.push({
            col: o.x,
            row: o.y,
            exit: true,
          });
      return m;
    }

// an empty model of the given size
  static function blank(w:Int, h:Int):Sewer
    {
      return {
        w: w,
        h: h,
        floor: [for (_ in 0...h) [for (_ in 0...w) false]],
        room: [for (_ in 0...h) [for (_ in 0...w) false]],
        lamps: [],
      };
    }

// a throwaway cave for the shader pre-warm (render.cave.CaveWarm): a chamber, a passage off it and a
// pillar, so every surface the real builder makes — floor, wall, rock top — gets built once, with one
// mouth so the mouth light is in the pool
  public static function demo():Sewer
    {
      var m = blank(16, 12);
      for (y in 2...9)
        for (x in 2...9)
          m.floor[y][x] = true;
      for (x in 9...14)
        for (y in 5...7)
          m.floor[y][x] = true;
      m.floor[5][5] = false;
      m.lamps.push({
        col: 5,
        row: 2,
        exit: true,
      });
      return m;
    }
}
