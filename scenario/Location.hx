// scenario location

package scenario;

class Location
{
  public var id: String; // unique location id
  public var name: String; // location name
  public var hasName: Bool; // does this location have name?
  public var area: RegionArea; // area link


  public function new(vid: String)
    {
      id = vid;
      name = 'unnamed location';
    }
}
