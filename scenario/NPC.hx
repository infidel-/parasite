// scenario npc 

package scenario;

class NPC 
{
  public var game: Game;

  public var name: String; // name
  public var nameKnown: Bool; // name known to player?
  public var type: String; // npc type
  public var job: String; // job title 
  public var jobKnown: Bool; // job known to player?
  public var area: RegionArea; // location area
  public var areaKnown: Bool; // location known to player?
  public var isDead: Bool; // is this npc dead?
  public var isDeadKnown: Bool; // is dead/alive known to player?
  public var memoryKnown: Bool; // has this npc's memories been learned? 
  public var event: Event; // event
  public var ai: ai.AI; // ai link

  public function new(g: Game)
    {
      game = g;
      type = 'civilian';
      name = 'John Doe';
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

      if (!isDeadKnown)
        {
          isDeadKnown = true;
          game.player.log('You have found out that '  + name + ' is ' +
            (isDead ? 'dead' : 'alive') + '.', COLOR_TIMELINE);
          return true;
        }

      return false;
    }


  public function toString()
    {
      return '' + name + ' ' + job + ' (' + area.x + ',' + area.y +
        ') dead:' + isDead + ' event:' + event.id;
    }
}
