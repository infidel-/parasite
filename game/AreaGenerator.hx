// area generation

package game;

import const.WorldConst;
import objects.*;
import game.AreaGame;

class AreaGenerator
{
  public static function generate(game: Game, area: AreaGame, info: AreaInfo)
    {
      if (info.type == 'city')
        generateBuildings(game, area, info);
      else if (info.type == 'wilderness')
        generateWilderness(game, area, info);
      else if (info.type == 'habitat')
        generateHabitat(game, area, info);
      else trace('AreaGenerator.generate(): unknown area type: ' + info.type);
        
      generateObjects(game, area, info);
    }


// generate a habitat
  static function generateHabitat (game: Game, area: AreaGame, info: AreaInfo)
    {
      Const.todo('habitat generator');
    }


// generate rocks, trees, etc
  static function generateWilderness(game: Game, area: AreaGame, info: AreaInfo)
    {
      var numStuff = Std.int(area.width * area.height / 20);
      for (i in 0...numStuff)
        {
          var x = Std.random(area.width);
          var y = Std.random(area.height);

          area.setCellType(x, y,
            (Std.random(100) < 50 ? Const.TILE_ROCK : Const.TILE_TREE));
        }
    }


// generate buildings
  static function generateBuildings(game: Game, area: AreaGame, info: AreaInfo)
    {
      // buildings
      for (y in 1...area.height)
        for (x in 1...area.width)
          {
            if (Math.random() > info.buildingChance)
              continue;

            // size
            var sx = 5 + Std.random(10);
            var sy = 5 + Std.random(10);

            if (x + sx > area.width - 1)
              sx = area.width - 1 - x;
            if (y + sy > area.height - 1)
              sy = area.height - 1 - y;

            if (sx < 2)
              continue;
            if (sy < 2)
              continue;

//            var cell = get(x,y);

            // check for adjacent buildings
            var ok = true;
            for (dy in -2...sy + 3)
              for (dx in -2...sx + 3)
                {
                  if (dx == 0 && dy == 0)
                    continue;
                  //var cell = get(x + dx, y + dy);
                  var cellType = area.getCellType(x + dx, y + dy);
                  if (cellType == "building")
                    {
                      ok = false;
                      break;
                    }
                }

            if (!ok)
              continue;
  
            // draw a building rect
            for (dy in 0...sy)
              for (dx in 0...sx)
                {
                  var cellType = area.getCellType(x + dx, y + dy);
                  if (cellType == null)
                    continue;

                  area.setCellType(x + dx, y + dy, Const.TILE_BUILDING);
                }
          }
    }


// generate objects
  static function generateObjects(game: Game, area: AreaGame, info: AreaInfo)
    {
      // spawn all objects
      for (objInfo in info.objects)
        for (i in 0...objInfo.amount)
          {
            // find free spot that is not close to another object like this
            var loc = null;
            var cnt = 0;
            while (true)
              {
                loc = area.findEmptyLocation();
                cnt++;
                if (cnt > 500)
                  {
                    trace('Area.generateObjects(): no free spot for another ' + 
                      objInfo.id + ', please report');
                    return;
                  }

                // check for close objects
                var ok = true;
                for (y in -3...3)
                  for (x in -3...3)
                    {
                      var olist = area.getObjectsAt(loc.x + x, loc.y + y);
                      for (o in olist)
                        if (o.type == objInfo.id)
                          {
                            ok = false;
                            break;
                          }

                      if (!ok)
                        break;
                    }

                if (ok)
                  break;
              }

            var o: AreaObject = null;
            if (objInfo.id == 'sewer_hatch')
              o = new SewerHatch(game, loc.x, loc.y);
              
            else throw 'unknown object type: ' + objInfo.id;

            area.addObject(o);
          }
    }
}
