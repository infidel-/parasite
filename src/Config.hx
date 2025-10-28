// game configuration

#if electron
import js.node.Fs;
#end
import haxe.Json;

import game.Game;
import jsui.UI;
import jsui.MainMenu;

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
  public var aiArtEnabled: Bool;

  public var font: String;
  public var fontSize: Int;
  public var fontTitle: String;
  public var hudLogLines: Int;
  public var mapScale: Float;
  public var minimapScale: Float;
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
      aiArtEnabled = true;

      font = 'Virtucorp';
      fontSize = 15;
      fontTitle = 'Cruiser2015';
      hudLogLines = 4;
      mapScale = 1;
      minimapScale = 1;
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
      map['aiArtEnabled'] = '1';

      map['font'] = font;
      map['fontSize'] = '' + fontSize;
      map['fontTitle'] = fontTitle;
      map['hudLogLines'] = '4';
      map['mapScale'] = '1';
      map['minimapScale'] = '1';
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
#else
      var str = js.Browser.window.localStorage.getItem('config');
      var obj = {};
      if (str != null)
        obj = Json.parse(str);

      for (f in Reflect.fields(obj))
        set(f, Reflect.field(obj, f));
#end
      UI.setVar('--text-font', font);
      UI.setVar('--text-font-size', fontSize + 'px');
      UI.setVar('--text-font-title', fontTitle);
      applyAiArtSetting();
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
#if electron
          electron.renderer.IpcRenderer.invoke('fullscreen' + val);
#end
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
      else if (key == 'aiArtEnabled')
        {
          aiArtEnabled = (val == '1');
          applyAiArtSetting();
        }

      else if (key == 'font')
        {
          font = val;
          jsui.UI.setVar('--text-font', font);
        }
      else if (key == 'fontSize')
        {
          fontSize = Std.parseInt(val);
          jsui.UI.setVar('--text-font-size', fontSize + 'px');
        }
      else if (key == 'fontTitle')
        {
          fontTitle = val;
          jsui.UI.setVar('--text-font-title', fontTitle);
        }
      else if (key == 'hudLogLines')
        hudLogLines = Const.clamp(Std.parseInt(val), 0, 10);
      else if (key == 'mapScale')
        mapScale = Const.clampFloat(Std.parseFloat(val), 0.1, 10);
      else if (key == 'minimapScale')
        minimapScale = Const.clampFloat(Std.parseFloat(val), 0.1, 10);
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

// update css to reflect ai art toggle
  function applyAiArtSetting()
    {
      UI.setVar('--message-img-display', aiArtEnabled ? 'block' : 'none');
      var bg = 'none';
      if (aiArtEnabled)
        {
          bg = 'url(./img/misc/bg1.jpg)';
          if (game.ui != null)
            {
              bg = game.ui.mainMenu.getBackgroundUrl();
            }
        }
      UI.setVar('--main-menu-bg', bg);
    }

  public static var fontsTitle = [
    'Alternity',
    'Cruiser2015',
    'DemunLotion',
    'Dusty',
    'FlipsideBrk',
    'Horizon',
    'Montalban',
    'Orkney-Regular',
    'Probert',
    'Rapier-Zero',
    'Rebellion',
    'Sigma-Five-Sans',
    'Sternbach',
    'Twobit',
    'Xolonium',
    'Zebulon',
  ];
  public static var fonts = [
    'Brainstorm',
    'Dusty',
    'Eurocorp',
    'Orkney-Regular',
    'Probert',
    'Schnaubelt',
    'Twobit',
    'Virtucorp',
    'Xball',
    'Xolonium',
  ];
}
