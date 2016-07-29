import haxe.macro.Expr;

class Version
{
  // get current game version from VERSION file
  public static macro function getVersion(): ExprOf<String>
    {
      var version = StringTools.trim(sys.io.File.getContent("VERSION"));
      return macro $v{version};
    }
}
