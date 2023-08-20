// game configuration

#if hl
import sys.io.File;
#elseif electron
import js.node.Fs;
#end
import haxe.Json;

import game.Game;

class Config
{
  var game: Game;

  public var mouseEnabled: Bool;
  public var extendedInfo: Bool;
  public var alwaysCenterCamera: Bool;
  public var laptopKeyboard: Bool;
  public var fullscreen: Bool;
  public var skipTutorial: Bool;
  public var shiftLongActions: Bool;
  // NOTE: new spoon vars will require fixing isSpoonMode() check!
  public var spoonEvolutionBasic: Bool;
  public var spoonHabitats: Bool;
  public var spoonHabitatAmbush: Bool;
  public var spoonNoSavesLimit: Bool;

  public var fontSize: Int;
  public var hudLogLines: Int;
  public var mapScale: Float;
  public var repeatDelay: Int;
  public var windowHeight: Int;
  public var windowWidth: Int;
  public var musicVolume: Int;
  public var effectsVolume: Int;
  public var ambientVolume: Int;
  public var difficulty: Int;

  var map: Map<String, String>;

  public function new(g: Game)
    {
      game = g;

      // default values
      mouseEnabled = true;
      extendedInfo = false;
#if mydebug
      extendedInfo = true;
#end
      alwaysCenterCamera = true;
      laptopKeyboard = false;
      fullscreen = false;
      skipTutorial = false;
      shiftLongActions = true;
      spoonEvolutionBasic = false;
      spoonHabitats = false;
      spoonHabitatAmbush = false;
      spoonNoSavesLimit = false;

      fontSize = 16;
      hudLogLines = 4;
      mapScale = 1;
      musicVolume = 30;
      effectsVolume = 40;
      ambientVolume = 30;
      repeatDelay = 100;
      windowHeight = 768;
      windowWidth = 1024;
      difficulty = 0;

      map = new Map();
      map['mouseEnabled'] = '1';
      map['extendedInfo'] = '0';
      map['alwaysCenterCamera'] = '1';
      map['laptopKeyboard'] = '0';
      map['shiftLongActions'] = '1';
      map['fullscreen'] = '0';
      map['skipTutorial'] = '0';
      map['spoonEvolutionBasic'] = '0';
      map['spoonHabitats'] = '0';
      map['spoonHabitatAmbush'] = '0';
      map['spoonNoSavesLimit'] = '0';

      map['fontSize'] = '' + fontSize;
      map['hudLogLines'] = '4';
      map['mapScale'] = '1';
      map['musicVolume'] = '' + musicVolume;
      map['effectsVolume'] = '' + effectsVolume;
      map['ambientVolume'] = '' + ambientVolume;
      map['repeatDelay'] = '' + repeatDelay;
      map['windowHeight'] = '' + windowHeight;
      map['windowWidth'] = '' + windowWidth;
      map['difficulty'] = '' + difficulty;

      game.debug('config load');
#if electron
      try {
        var s = Fs.readFileSync('settings.json', 'utf8');
        var obj = Json.parse(s);
        for (f in Reflect.fields(obj))
          set(f, Reflect.field(obj, f));
      }
      catch (e: Dynamic)
        {
          trace(e);
        }
      // apply options
      jsui.UI.setVar('--text-font-size', fontSize + 'px');
#elseif js
      var str = js.Browser.window.localStorage.getItem('config');
      var obj = {};
      if (str != null)
        obj = Json.parse(str);

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

// check if any spoon vars enabled
  public function isSpoonMode(): Bool
    {
      return (spoonEvolutionBasic ||
        spoonHabitats ||
        spoonHabitatAmbush ||
        spoonNoSavesLimit);
    }

// set option to value and save config
  public function set(key: String, val: String, ?doSave = false)
    {
      var key = StringTools.trim(key);
      var val = StringTools.trim(val);

      if (key == 'mouseEnabled')
        mouseEnabled = (val == '1');
      else if (key == 'extendedInfo')
        extendedInfo = (val == '1');
      else if (key == 'alwaysCenterCamera')
        alwaysCenterCamera = (val == '1');
      else if (key == 'laptopKeyboard')
        laptopKeyboard = (val == '1');
      else if (key == 'shiftLongActions')
        shiftLongActions = (val == '1');
      else if (key == 'fullscreen')
        {
          fullscreen = (val == '1');
          electron.renderer.IpcRenderer.invoke('fullscreen' + val);
        }
      else if (key == 'skipTutorial')
        skipTutorial = (val == '1');
      else if (key == 'spoonEvolutionBasic')
        spoonEvolutionBasic = (val == '1');
      else if (key == 'spoonHabitats')
        spoonHabitats = (val == '1');
      else if (key == 'spoonHabitatAmbush')
        spoonHabitatAmbush = (val == '1');
      else if (key == 'spoonNoSavesLimit')
        spoonNoSavesLimit = (val == '1');

      else if (key == 'fontSize')
        {
          fontSize = Std.parseInt(val);
        }
      else if (key == 'hudLogLines')
        hudLogLines = Const.clamp(Std.parseInt(val), 0, 10);
      else if (key == 'mapScale')
        mapScale = Const.clampFloat(Std.parseFloat(val), 0.1, 10);
      else if (key == 'musicVolume')
        musicVolume = Const.clamp(Std.parseInt(val), 0, 100);
      else if (key == 'effectsVolume')
        effectsVolume = Const.clamp(Std.parseInt(val), 0, 100);
      else if (key == 'ambientVolume')
        ambientVolume = Const.clamp(Std.parseInt(val), 0, 100);
      else if (key == 'repeatDelay')
        repeatDelay = Std.parseInt(val);
      else if (key == 'windowHeight')
        windowHeight = Std.parseInt(val);
      else if (key == 'windowWidth')
        windowWidth = Std.parseInt(val);
      else if (key == 'difficulty')
        difficulty = Std.parseInt(val);

      else
        {
          game.debug('No such config setting [' + key + '].');
          return;
        }

      map.set(key, val);

      // save config
      if (doSave)
        save(true);
    }


// dump current config
  public function dump(isHTML: Bool)
    {
      var s = new StringBuf();
      for (key in map.keys())
        s.add(key + ' = ' + map[key] + (isHTML ? '<br/>' : '\n'));
      game.log(s.toString(), COLOR_DEBUG);
    }


// save config
  public function save(needRestart: Bool)
    {
      game.debug('config save');
#if electron
      var obj = {};
      for (k => v in map)
        Reflect.setField(obj, k, v);
      Fs.writeFileSync('settings.json',
        Json.stringify(obj, null, '  '), 'utf8');
#elseif js
      var obj = {};
      for (key in map.keys())
        Reflect.setField(obj, key, map[key]);
      var str = haxe.Json.stringify(obj);
      js.Browser.window.localStorage.setItem('config', str);

      if (needRestart)
        game.log('Config saved. Reload page to apply new settings.');
#else
      var s = new StringBuf();
      for (key in map.keys())
        s.add(key + ' = ' + map[key] + '\n');
      sys.io.File.saveContent('parasite.cfg', s.toString());
#end
    }
}
