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
/*
  public static macro function getBuild(): ExprOf<String>
    {
      var date = Date.now();
      Sys.command('make', [ 'count' ]);
      var count = sys.io.File.getContent('COUNT');
      Sys.command('rm', [ 'COUNT' ]);
      var str = DateTools.format(date, "%Y%m%d-") +
        StringTools.trim(count);
      return macro $v{str};
    }*/
}
