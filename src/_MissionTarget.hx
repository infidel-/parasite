// mission target info
@:structInit
class _MissionTarget extends _SaveObject
{
  public var isMale: Bool;
  public var job: String;
  public var icon: String;
  public var type: String;
  public var lang: String;
  public var location: _AreaType;
  public var helpAvailable: Bool;
  
  public function new(?isMale: Bool, ?job: String, ?icon: String, ?type: String, ?lang: String, ?helpAvailable: Bool, location: _AreaType)
    {
      this.isMale = isMale;
      this.job = job;
      this.icon = icon;
      this.type = type;
      this.lang = lang;
      this.location = location;
      this.helpAvailable = helpAvailable;
    }
}
