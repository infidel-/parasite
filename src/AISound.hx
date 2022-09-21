// AI sound with parameters
@:structInit
class AISound
{
  @:optional public var text: String; // AI text to display
  public var radius: Int; // radius this sound propagates to (can be 0)
  public var alertness: Int; // amount of alertness that AIs in this radius gain
  @:optional public var params: Dynamic; // state-specific parameters
  @:optional public var file: String; // sound files prefix

  public function new(?text: String, radius: Int, alertness: Int,
      ?params: Dynamic, ?file: String)
    {
      this.text = text;
      this.radius = radius;
      this.alertness = alertness;
      this.params = params;
      this.file = file;
    }
}
