// game configuration

import sys.io.File;

class Config
{
  // cached values
  public var extendedInfo: Bool;
  public var sendExceptions: Bool;

  public var fontSize: Int;
  public var windowWidth: Int;
  public var windowHeight: Int;

  var map: Map<String, String>;

  public function new()
    {
      map = new Map();
      var str = File.getContent("./parasite.cfg");
      var arr = str.split("\n");

      // default values
      extendedInfo = false;
      sendExceptions = false;
      fontSize = 16;
      windowWidth = 1024;
      windowHeight = 768;

      for (line in arr)
        {
          line = StringTools.trim(line);
          if (line.charAt(0) == '#') // comments
            continue;
          if (line.length == 0) // empty line
            continue;

          var tmp = line.split('=');
          var key = StringTools.trim(tmp[0]);
          var val = StringTools.trim(tmp[1]);
          map.set(key, val);

          if (key == 'extendedInfo')
            extendedInfo = (val == '1');
          else if (key == 'sendExceptions')
            sendExceptions = (val == '1');
          else if (key == 'fontSize')
            fontSize = Std.parseInt(val);
          else if (key == 'windowWidth')
            windowWidth = Std.parseInt(val);
          else if (key == 'windowHeight')
            windowHeight = Std.parseInt(val);
        }
    }
}
