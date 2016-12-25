import haxe.macro.Expr;

class Version
{
// get current game version from VERSION file
  public static macro function getVersion(): ExprOf<String>
    {
      var version = StringTools.trim(sys.io.File.getContent("VERSION"));
      return macro $v{version};
    }


// get current build
  public static macro function getBuild(): ExprOf<String>
    {
      var date = Date.now();
      var str = DateTools.format(date, "%Y%m%d-%H%M");
      return macro $v{str};
    }
}
