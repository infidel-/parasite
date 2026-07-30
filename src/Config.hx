// game configuration

import haxe.Json;

import game.Game;
import ui.UI;
import ui.MainMenu;

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
  public var compactHud: Bool;
  public var hudDebugCollapsed: Bool;
  // NOTE: new spoon vars will require fixing isSpoonMode() check!
  public var spoonEvolutionBasic: Bool;
  public var spoonHabitats: Bool;
  public var spoonHabitatAmbush: Bool;
  public var spoonNoSavesLimit: Bool;
  public var aiArtEnabled: Bool;
  public var vidShowFps: Bool;
  public var vidAntialias: Int;
  public var vidRenderScale: Int; // backbuffer pixels per CSS pixel, in percent (see render.View.setRenderScale)
  public var vidLampLights: Int;  // live lamp spotlights (see render.View.setLampLights); 0 = none
  public var vidAO: Bool;
  public var vidBloom: Bool;      // window/lamp glow post pass (see render.View.setBloom); off is a pure perf trade

  public var font: String;
  public var fontSize: Int;
  public var fontTitle: String;
  public var hudLogLines: Int;
  public var vidFpsCap: Int;
  public var mapScale: Float;
  public var minimapScale: Float;
  public var repeatDelay: Int;
  public var windowHeight: Int;
  public var windowWidth: Int;
  public var musicVolume: Int;
  public var effectsVolume: Int;
  public var ambientVolume: Int;
  public var difficulty: Int;

  // raw mod-id → settings bucket (§8.5); read/written via mods.ModSettings facade.
  // structured JSON (any field types), not the flat string map used by built-in config keys
  public var mods: Dynamic;

  var map: Map<String, String>;

  public function new(g: Game)
    {
      game = g;

      // default values
      mouseEnabled = true;
      extendedInfo = Const.isDebug;
      alwaysCenterCamera = true;
      laptopKeyboard = false;
      fullscreen = false;
      skipTutorial = false;
      shiftLongActions = true;
      compactHud = false;
      hudDebugCollapsed = false;
      spoonEvolutionBasic = false;
      spoonHabitats = false;
      spoonHabitatAmbush = false;
      spoonNoSavesLimit = false;
      aiArtEnabled = true;
      vidShowFps = false;
      vidFpsCap = 60;
      vidAntialias = 4;
      // 100% = one backbuffer pixel per CSS pixel. was min(devicePixelRatio, 1.25), i.e. 1.56x the
      // pixels on any 125%-scaled display, and measured at ~80% of the street-view GPU frame
      vidRenderScale = 100;
      // seeded from the art value so RenderConfig stays the single source of truth for the default
      // look; lowering it is a perf trade that visibly shortens how far lamp light reaches
      vidLampLights = render.RenderConfig.LAMP_LIGHT.pool;
      vidAO = false;
      // on: bloom is what the night look is authored around (lit windows, tracers, the move-path
      // line). the largest single removable pass, so it is offered — but never off by default
      vidBloom = true;

      font = 'Virtucorp';
      fontSize = 14;
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
      mods = {};

      map = new Map();
      map['mouseEnabled'] = '1';
      map['extendedInfo'] = '0';
      map['alwaysCenterCamera'] = '1';
      map['laptopKeyboard'] = '0';
      map['shiftLongActions'] = '1';
      map['compactHud'] = '0';
      map['hudDebugCollapsed'] = '0';
      map['fullscreen'] = '0';
      map['skipTutorial'] = '0';
      map['spoonEvolutionBasic'] = '0';
      map['spoonHabitats'] = '0';
      map['spoonHabitatAmbush'] = '0';
      map['spoonNoSavesLimit'] = '0';
      map['aiArtEnabled'] = '1';
      map['vidShowFps'] = '0';
      map['vidFpsCap'] = '60';
      map['vidAntialias'] = '4';
      map['vidRenderScale'] = '100';
      map['vidLampLights'] = '' + vidLampLights;
      map['vidAO'] = '0';
      map['vidBloom'] = '1';

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
        var s = HostBridge.settingsRead();
        if (s != null)
          {
            var obj = Json.parse(s);
            loadFromObj(obj);
          }
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

      loadFromObj(obj);
#end
      UI.setVar('--text-font', font);
      UI.setVar('--text-font-size', fontSize + 'px');
      UI.setVar('--text-font-title', fontTitle);
      applyAiArtSetting();
    }

// apply persisted settings object: mods subtree is structured JSON, rest is flat string map
  function loadFromObj(obj: Dynamic)
    {
      var rawMods = Reflect.field(obj, 'mods');
      if (rawMods != null)
        mods = rawMods;
      for (f in Reflect.fields(obj))
        {
          if (f == 'mods')
            continue;
          set(f, Reflect.field(obj, f));
        }
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
      else if (key == 'vidShowFps')
        vidShowFps = (val == '1');
      // settings.json is user-editable (trust boundary): guard the frame cap so a bad
      // value can't become 1000/0 = Infinity and stall the street-view render loop
      else if (key == 'vidFpsCap')
        {
          vidFpsCap = Std.parseInt(val);
          if (vidFpsCap == null ||
              vidFpsCap <= 0)
            vidFpsCap = 60;
        }
      // settings.json is user-editable (trust boundary): only 0/2/4/8 are valid MSAA
      // sample counts, snap anything else to 4 so a bad value can't break the composer
      else if (key == 'vidAntialias')
        {
          vidAntialias = Std.parseInt(val);
          if (vidAntialias != 0 &&
              vidAntialias != 2 &&
              vidAntialias != 4 &&
              vidAntialias != 8)
            vidAntialias = 4;
        }
      // same trust boundary as the MSAA count above: clamp to the offered range rather than trusting
      // a hand-edited number, since this one sizes every render target
      else if (key == 'vidRenderScale')
        {
          vidRenderScale = Std.parseInt(val);
          if (vidRenderScale == null ||
              vidRenderScale < 50 ||
              vidRenderScale > 200)
            vidRenderScale = 100;
        }
      // 0 is meaningful here (no lamp spotlights at all); the upper bound only stops a hand-edited
      // number from unrolling an absurd spot loop into every material
      else if (key == 'vidLampLights')
        {
          vidLampLights = Std.parseInt(val);
          if (vidLampLights == null ||
              vidLampLights < 0 ||
              vidLampLights > 16)
            vidLampLights = render.RenderConfig.LAMP_LIGHT.pool;
        }
      else if (key == 'vidAO')
        vidAO = (val == '1');
      else if (key == 'vidBloom')
        vidBloom = (val == '1');
      else if (key == 'laptopKeyboard')
        laptopKeyboard = (val == '1');
      else if (key == 'shiftLongActions')
        shiftLongActions = (val == '1');
      else if (key == 'compactHud')
        compactHud = (val == '1');
      else if (key == 'hudDebugCollapsed')
        hudDebugCollapsed = (val == '1');
      else if (key == 'fullscreen')
        {
          fullscreen = (val == '1');
#if electron
          HostBridge.setFullscreen(val == '1');
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
          ui.UI.setVar('--text-font', font);
        }
      else if (key == 'fontSize')
        {
          fontSize = Std.parseInt(val);
          ui.UI.setVar('--text-font-size', fontSize + 'px');
        }
      else if (key == 'fontTitle')
        {
          fontTitle = val;
          ui.UI.setVar('--text-font-title', fontTitle);
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
      // sorted keys so settings.json is stable/diffable (mods subtree appended last)
      var keys = [for (k in map.keys()) k];
      keys.sort(Reflect.compare);
#if electron
      var obj = {};
      for (k in keys)
        Reflect.setField(obj, k, map[k]);
      Reflect.setField(obj, 'mods', mods);
      HostBridge.settingsWrite(Json.stringify(obj, null, '  '));
#elseif js
      var obj = {};
      for (k in keys)
        Reflect.setField(obj, k, map[k]);
      Reflect.setField(obj, 'mods', mods);
      var str = haxe.Json.stringify(obj);
      js.Browser.window.localStorage.setItem('config', str);

      if (needRestart)
        game.log('Config saved. Reload page to apply new settings.');
#else
      var s = new StringBuf();
      for (k in keys)
        s.add(k + ' = ' + map[k] + '\n');
      sys.io.File.saveContent('parasite.cfg', s.toString());
#end
    }

// update css to reflect ai art toggle
  function applyAiArtSetting()
    {
      UI.setVar('--message-img-display', aiArtEnabled ? 'block' : 'none');
      if (game.ui != null)
        {
          var menuGL = game.ui.mainMenu.menuGL;
          menuGL.setBgEnabled(aiArtEnabled);
          if (aiArtEnabled)
            menuGL.setBackground(game.ui.mainMenu.getBackgroundUrl());
        }
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
