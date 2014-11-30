// scenario npc 

package scenario;

class NPC 
{
  public var game: Game;

  public var name: String; // name
  public var nameKnown: Bool; // name known to player?
  public var type: String; // ai type 
  public var job: String; // job title 
  public var jobKnown: Bool; // job known to player?
  public var area: RegionArea; // location area
  public var areaKnown: Bool; // location known to player?
  public var isDead: Bool; // is this npc dead?
  public var isDeadKnown: Bool; // is dead known to player?
  public var event: Event; // event

  public function new()
    {
      type = 'civilian';
      name = 'John Doe';
    }


  public function toString()
    {
      return '' + name + ' ' + job + ' (' + area.x + ',' + area.y +
        ') dead:' + isDead + ' event:' + event.id;
    }
}
