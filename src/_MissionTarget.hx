// mission target info
@:structInit
class _MissionTarget
{
  public var isMale: Bool;
  public var job: String;
  public var icon: String;
  public var type: String;
  public var location: _AreaType;
  
  public function new(?isMale: Bool, ?job: String, ?icon: String, ?type: String, location: _AreaType)
    {
      this.isMale = isMale;
      this.job = job;
      this.icon = icon;
      this.type = type;
      this.location = location;
    }
}
