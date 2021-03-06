// scenario npc

package scenario;

import game.Game;
import game.AreaGame;

class NPC
{
  public var game: Game;

  public var name: String; // name
  public var nameKnown: Bool; // name known to player?
  public var type: String; // npc type
  public var job: String; // job title
  public var jobKnown: Bool; // job known to player?
  public var area: AreaGame; // location area
  public var areaKnown: Bool; // location known to player?
  public var isMale: Bool; // gender
  public var isDead: Bool; // is this npc dead?
  public var statusKnown: Bool; // is dead/alive status known to player?
  public var memoryKnown: Bool; // has this npc's memories been learned?
  public var event: Event; // event (can be null)
  public var ai: ai.AI; // ai link

  public var id: Int; // unique NPC id
  static var _maxID: Int = 0; // current max ID

  public function new(g: Game)
    {
      game = g;
      isMale = (Std.random(100) < 50 ? true : false);
      name = const.NameConst.getHumanName(isMale);
      nameKnown = false;
      type = 'civilian';
      job = null;
      jobKnown = false;
      area = null;
      areaKnown = false;
      isDead = false;
      statusKnown = false;
      memoryKnown = false;
      event = null;
      ai = null;

      id = (_maxID++);
    }


// is this NPC fully researched?
  public inline function fullyKnown()
    {
      return (nameKnown && jobKnown && areaKnown && statusKnown);
    }


// fully research NPC with computer
  public function researchFull()
    {
      nameKnown = true;
      jobKnown = true;
      areaKnown = true;
      statusKnown = true;
      game.player.log('You have found out everything about '  + name +
        ' (' + (isDead ? 'deceased' : 'alive') + ').', COLOR_TIMELINE);
    }


// research this npc with computer
  public function research(): Bool
    {
      if (!nameKnown)
        {
          nameKnown = true;
          game.player.log('You have found out a name: '  + name + '.',
            COLOR_TIMELINE);
          return true;
        }

      if (!jobKnown)
        {
          jobKnown = true;
          game.player.log('You have found out the job and photo of '  + name + '.',
            COLOR_TIMELINE);
          return true;
        }

      if (!areaKnown)
        {
          areaKnown = true;
          game.player.log('You have found out the location of '  + name + '.',
            COLOR_TIMELINE);
          return true;
        }

      if (!statusKnown)
        {
          statusKnown = true;
          game.player.log('You have found out that '  + name + ' is ' +
            (isDead ? 'dead' : 'alive') + '.', COLOR_TIMELINE);
          return true;
        }

      return false;
    }


  public function toString()
    {
      return '{ ' + name + ', ' + job + ', (' + area.x + ',' + area.y +
        '), dead: ' + isDead +
        ', statusKnown: ' + statusKnown +
        ', event: ' + (event != null ? event.id : 'null') + ' }';
    }
}
