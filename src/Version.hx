import haxe.macro.Expr;

class Version
{
// get current game version from VERSION file
  public static macro function getVersion(): ExprOf<String>
    {
      // resolve via classpath so callers compiled from any cwd work
      var path = haxe.macro.Context.resolvePath("VERSION");
      // the compile server caches macro output; re-run when VERSION changes
      haxe.macro.Context.registerModuleDependency(haxe.macro.Context.getLocalModule(), path);
      var version = StringTools.trim(sys.io.File.getContent(path));
      return macro $v{version};
    }

// get the changelog (changes.md in the repo root, next to src/) for the main menu viewer
  public static macro function getChangelog(): ExprOf<String>
    {
      var dir = haxe.io.Path.directory(
        sys.FileSystem.fullPath(haxe.macro.Context.resolvePath("VERSION")));
      var path = haxe.io.Path.join([ dir, '..', 'changes.md' ]);
      // the compile server caches macro output; re-run when changes.md changes
      haxe.macro.Context.registerModuleDependency(haxe.macro.Context.getLocalModule(), path);
      return macro $v{sys.io.File.getContent(path)};
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
