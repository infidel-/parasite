@:structInit class _OvumInfo extends _SaveObject
{
  public var level: Int;
  public var xp: Int;

  public function new(level: Int, xp: Int)
    {
      this.level = level;
      this.xp = xp;
    }
}
