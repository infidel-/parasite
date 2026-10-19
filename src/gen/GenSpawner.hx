// turn a finished generation's spawn intents into real objects
//
// THE ONLY PLACE UNDER gen/ THAT TOUCHES A Game, and it is only ever called on the live path.
// Everything above it works on gen._GenSpawn records, which is what lets the whole generator run
// under tools/genrun.mjs; this is the seam where that ends and the running game begins.
//
// if you are adding a new kind of generated object: record it as a spawn where it is decided, and
// build it here. Constructing it in the generator instead re-couples generation to the renderer
// (AreaObject.initPost -> createEntity -> ObjectEntity) and breaks the headless oracle.

package gen;

import game.AreaGame;
import game.Game;
import objects.*;
import tiles.UndergroundLab;

class GenSpawner
{
// build every recorded spawn into the area, in the order it was recorded.
//
// order matters for exactly one reason: two spawns on one cell would leave whichever landed second
// on top, and the generator's own placement gates (GenCtx.hasObjectAt) are what stop that happening
// at all — so this does not re-check, it just builds
  public static function drain(game: Game, area: AreaGame, ctx: GenCtx)
    {
      // a lab doorway's first door, linked to the second when it comes
      var half: Door = null;
      for (s in ctx.spawns)
        {
          var o: AreaObject = switch (s.type)
            {
              case 'decoration':
                new Decoration(game, area.id, s.x, s.y, s.row, s.col);
              case 'door':
                new Door(game, area.id, s.x, s.y,
                  {
                    row: s.row,
                    col: s.col,
                  },
                  {
                    row: s.row,
                    col: s.col2,
                  });
              case 'vent':
                new Vent(game, area.id, s.x, s.y);
              // a mountain cave habitat's exit, gen.cave.CaveGen. the same habitat_exit object the
              // sewer habitat leaves by; the name is what the renderer and the HUD tell it apart by
              case 'caveMouth':
                var exit = new objects.mission.HabitatExit(game, area.id, s.x, s.y);
                exit.name = 'cave mouth';
                exit;
              case 'sewerHatch':
                new SewerHatch(game, area.id, s.x, s.y);
              case 'floorDrain':
                new FloorDrain(game, area.id, s.x, s.y);
              // the corp tower's two vertical exits. the lift is NINE of these, one per cell of the
              // car, which is how it has always been built — gen.blocks.ElevatorBlock records them
              case 'elevator':
                new Elevator(game, area.id, s.x, s.y);
              case 'stairs':
                new Stairs(game, area.id, s.x, s.y);
              // a security room's gun cabinet, gen.corp.CorpRooms.security
              case 'gunCabinet':
                new GunCabinet(game, area.id, s.x, s.y);
              // a military armory's lockers and its safe, gen.military.MilitaryRooms.gunCabinet/safe/lockers
              case 'locker':
                new Locker(game, area.id, s.x, s.y);
              case 'safe':
                new Safe(game, area.id, s.x, s.y);
              // the underground lab's lift car, four parts on the lab's own atlas, and its two-cell
              // doorways, gen.lab.LabGen
              case 'labLift':
                new Elevator(game, area.id, s.x, s.y, -1, s.part, UndergroundLab.OBJECTS_IMAGE);
              case 'labDoor':
                var d = labDoor(game, area, s);
                if (s.part == 0)
                  half = d;
                else
                  {
                    d.linkedDoorID = half.id;
                    half.linkedDoorID = d.id;
                  }
                d;
              default:
                trace('GenSpawner.drain(): unknown spawn type "' + s.type + '" at ' +
                  s.x + ',' + s.y);
                null;
            }
          if (o != null)
            area.addObject(o);
        }
    }

// one door of a lab doorway, with the lab atlas's frames for its half of the pair
  static function labDoor(game: Game, area: AreaGame, s: _GenSpawn): Door
    {
      return (s.vertical ?
        (s.part == 0 ?
          new Door(game, area.id, s.x, s.y, UndergroundLab.DOOR_VERTICAL_CLOSED_UPPER,
            UndergroundLab.DOOR_VERTICAL_OPEN_UPPER, UndergroundLab.OBJECTS_IMAGE) :
          new Door(game, area.id, s.x, s.y, UndergroundLab.DOOR_VERTICAL_CLOSED_LOWER,
            UndergroundLab.DOOR_VERTICAL_OPEN_LOWER, UndergroundLab.OBJECTS_IMAGE)) :
        (s.part == 0 ?
          new Door(game, area.id, s.x, s.y, UndergroundLab.DOOR_HORIZONTAL_CLOSED_LEFT,
            UndergroundLab.DOOR_HORIZONTAL_OPEN_LEFT, UndergroundLab.OBJECTS_IMAGE) :
          new Door(game, area.id, s.x, s.y, UndergroundLab.DOOR_HORIZONTAL_CLOSED_RIGHT,
            UndergroundLab.DOOR_HORIZONTAL_OPEN_RIGHT, UndergroundLab.OBJECTS_IMAGE)));
    }
}
