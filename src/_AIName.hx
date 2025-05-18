// AI name structure
@:structInit
class _AIName extends _SaveObject
{
  public var real: String; // real name
  public var realCapped: String; // capitalized real name
  public var unknown: String; // class name
  public var unknownCapped: String; // class name capitalized

  public function new(real: String, realCapped: String, unknown: String, unknownCapped: String)
    {
      this.real = real;
      this.realCapped = realCapped;
      this.unknown = unknown;
      this.unknownCapped = unknownCapped;
    }
}
