// game configuration

import sys.io.File;

class Config
{
  // cached values
  public var extendedInfo: Bool;
  public var sendExceptions: Bool;

  var map: Map<String, String>;

  public function new()
    {
      map = new Map();
      var str = File.getContent("./parasite.cfg");
      var arr = str.split("\n");

      // default values
      extendedInfo = false;
      sendExceptions = false;

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
          if (key == 'sendExceptions')
            sendExceptions = (val == '1');
        }
    }
}
