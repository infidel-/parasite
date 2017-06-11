// game configuration

#if !js
import sys.io.File;
#end

import game.Game;

class Config
{
  var game: Game;

  // cached values
  public var extendedInfo: Bool;
  public var sendExceptions: Bool;

  public var hudLogLines: Int;
  public var fontSize: Int;
  public var fontSizeLarge: Int;
  public var windowWidth: Int;
  public var windowHeight: Int;
  public var pathDelay: Int;

  var map: Map<String, String>;

  public function new(g: Game)
    {
      game = g;

      // default values
      extendedInfo = false;
      hudLogLines = 4;
      sendExceptions = false;
      fontSize = 16;
      fontSizeLarge = 24;
      windowWidth = 1024;
      windowHeight = 768;
      pathDelay = 50;

      map = new Map();
      map['extendedInfo'] = '0';
      map['hudLogLines'] = '4';
      map['sendExceptions'] = '0';
      map['fontSize'] = '' + fontSize;
      map['windowWidth'] = '' + windowWidth;
      map['windowHeight'] = '' + windowHeight;
      map['pathDelay'] = '' + pathDelay;

#if js
      var str = js.Browser.window.localStorage.getItem('config');
      var obj = {};
      if (str != null)
        obj = haxe.Json.parse(str);

      for (f in Reflect.fields(obj))
        set(f, Reflect.field(obj, f));
#else
      var str = '';
      var arr = [];

      try {
        str = File.getContent("./parasite.cfg");
        arr = str.split("\n");
        }
      catch (e: Dynamic)
        {}

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

          set(key, val);
        }
#end
    }


// set option to value and save config
  public function set(key: String, val: String, ?doSave = false)
    {
      var key = StringTools.trim(key);
      var val = StringTools.trim(val);

      if (key == 'extendedInfo')
        extendedInfo = (val == '1');
      else if (key == 'hudLogLines')
        hudLogLines = Const.clamp(Std.parseInt(val), 0, 10);
      else if (key == 'sendExceptions')
        sendExceptions = (val == '1');
      else if (key == 'fontSize')
        {
          fontSize = Std.parseInt(val);
          if (fontSize < 8)
            fontSize = 8;
          fontSizeLarge = Std.int(fontSize * 1.5);
        }
      else if (key == 'windowWidth')
        windowWidth = Std.parseInt(val);
      else if (key == 'windowHeight')
        windowHeight = Std.parseInt(val);
      else if (key == 'pathDelay')
        pathDelay = Std.parseInt(val);

      else
        {
          game.debug('No such config setting [' + key + '].');
          return;
        }

      map.set(key, val);

      // save config
      if (doSave)
        save();
    }


// dump current config
  public function dump()
    {
      for (key in map.keys())
        game.debug(key + ' = ' + map[key]);
    }


// save config
  public function save()
    {
#if js
      var obj = {};
      for (key in map.keys())
        Reflect.setField(obj, key, map[key]);
      var str = haxe.Json.stringify(obj);
      js.Browser.window.localStorage.setItem('config', str);

      game.debug('Config saved. Reload page to apply new settings.');
#else
      Const.todo('config saving!');
#end
    }
}
