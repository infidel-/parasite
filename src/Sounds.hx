// sounds and music manager
import game.Game;
#if electron
import js.node.Fs;
#end
import js.Browser;

class Sounds
{
  var musicIdx: Int;
  var scene: GameScene;
  var game: Game;
  var sounds: Map<String, Array<Int>>;
  var lastPlayedTS: Map<String, Float>;
  var locationType: String;
  var music: SMSound;
  var menuMusic: SMSound;
  var aboutMusic: SMSound;
  var ambient: _SoundInfo; 
  var ambientNext: _SoundInfo;
  var ambientLocation: _SoundAmbientLocation;
  var initDone: Bool;

  public function new(s: GameScene)
    {
      scene = s;
      initDone = false;
      sounds = new Map();
      lastPlayedTS = new Map();
      game = scene.game;
      locationType = 'none';
      ambient = {
        id: 'ambient',
        sound: null,
        state: SOUND_STOPPED,
      };
      ambientNext = {
        id: 'ambientNext',
        sound: null,
        state: SOUND_STOPPED,
      };
      Browser.window.setInterval(function () {
        if (!initDone)
          return;
        if (game.ui.state == UISTATE_MAINMENU ||
            game.ui.state == UISTATE_NEWGAME ||
            game.ui.state == UISTATE_OPTIONS ||
            game.ui.state == UISTATE_PEDIA ||
            game.ui.state == UISTATE_PRESETS)
          {
            if (menuMusic.playState == 0)
              menuMusic.play();
            else if (menuMusic.paused)
              menuMusic.resume();
            if (aboutMusic.playState == 1 &&
                !aboutMusic.paused)
              aboutMusic.pause();
            if (music.playState == 1 && !music.paused)
              music.pause();
            if (ambient.state != SOUND_STOPPED &&
                !ambient.sound.muted)
              ambient.sound.mute();
            if (ambientNext.state != SOUND_STOPPED &&
                !ambientNext.sound.muted)
              ambientNext.sound.mute();
            return;
          }
        else if (game.ui.state == UISTATE_ABOUT)
          {
            if (menuMusic.playState == 1 &&
                !menuMusic.paused)
              menuMusic.pause();
            if (music.playState == 1 && !music.paused)
              music.pause();
            if (aboutMusic.playState == 0)
              aboutMusic.play();
            else if (aboutMusic.paused)
              aboutMusic.resume();
            return;
          }
        else
          {
            if (menuMusic.playState == 1 &&
                !menuMusic.paused)
              menuMusic.pause();
            if (aboutMusic.playState == 1 &&
                !aboutMusic.paused)
              aboutMusic.pause();
            if (music.playState == 0)
              music.play();
            else if (music.paused)
              music.resume();
            if (ambient.state != SOUND_STOPPED &&
                ambient.sound.muted)
              ambient.sound.unmute();
            if (ambientNext.state != SOUND_STOPPED &&
                ambientNext.sound.muted)
              ambientNext.sound.unmute();
          }
        ambientTick(ambient);
        ambientTick(ambientNext);
      }, 15);
      ambientLocation = AMBIENT_NONE;
      music = null;
      menuMusic = null;
      aboutMusic = null;
      SoundManager.setup({
        debugMode: false,
        waitForWindowLoad: true,
        useHTML5Audio: true,
        onready: init,
      });
    }

// init sounds and music
  function init()
    {
      sounds = new Map();
#if !free
#if electron
      // read all existing sound file names
      var files = Fs.readdirSync('resources/app/sound/');
      for (f in files)
        {
          if (!StringTools.endsWith(f, '.mp3'))
            continue;
          var name = f.substr(0, f.indexOf('.'));
          var last = name.charCodeAt(name.length - 1);
          // 0-9
          if (last >= 48 && last <= 57)
            {
              name = name.substr(0, name.length - 1);
              last -= 48;
            }
          else last = -1;
          var tmp = sounds[name];
          if (tmp == null)
            {
              tmp = [];
              sounds[name] = tmp;
            }
          tmp.push(last);
        }
#else
      sounds['action-acid-spit'] = [-1];
      sounds['action-fail'] = [-1];
      sounds['action-gas'] = [-1];
      sounds['action-paralysis-spit'] = [-1];
      sounds['action-probe'] = [-1];
      sounds['action-slime-spit'] = [-1];
      sounds['action-spaceship-install'] = [-1];
      sounds['action-spaceship-start'] = [-1];
      sounds['ai-arrive-police'] = [-1];
      sounds['ai-arrive-security'] = [-1];
      sounds['ai-arrive-soldier'] = [-1];
      sounds['ai-phone'] = [-1];
      sounds['ai-radio'] = [-1];
      sounds['ambient-city'] = [1];
      sounds['ambient-corp'] = [1];
      sounds['ambient-facility'] = [1];
      sounds['ambient-habitat'] = [1];
      sounds['ambient-military'] = [1];
      sounds['ambient-region'] = [1];
      sounds['ambient-wilderness'] = [1];
      sounds['attack-assault-rifle'] = [1];
      sounds['attack-baton'] = [1, 2, 3];
      sounds['attack-bite'] = [1, 2, 3];
      sounds['attack-bullet-glass'] = [1, 2, 3];
      sounds['attack-bullet-hit'] = [1, 2, 3, 4, 5];
      sounds['attack-bullet-miss'] = [1, 2, 3, 4];
      sounds['attack-fists'] = [1, 2, 3];
      sounds['attack-pistol'] = [1, 2];
      sounds['attack-shotgun'] = [1];
      sounds['attack-stun-rifle'] = [1, 2];
      sounds['attack-stunner'] = [1, 2];
      sounds['click-action'] = [-1];
      sounds['click-hud'] = [-1];
      sounds['click-menu'] = [-1];
      sounds['click-submenu'] = [-1];
      sounds['dog-bark'] = [1];
      sounds['dog-die'] = [1];
      sounds['dog-growl'] = [1];
      sounds['dog-whimper'] = [1];
      sounds['dog-whine'] = [1];
      sounds['dog-yelp'] = [1];
      sounds['door-cabinet-close'] = [1];
      sounds['door-cabinet-open'] = [1, 2];
      sounds['door-double-close'] = [1];
      sounds['door-double-open'] = [1];
      sounds['door-elevator-close'] = [1];
      sounds['door-elevator-open'] = [1];
      sounds['door-glass-close'] = [1, 2];
      sounds['door-glass-open'] = [1, 2, 3];
      sounds['door-keycard-unlock'] = [-1];
      sounds['door-metal-close'] = [1];
      sounds['door-metal-open'] = [1];
      sounds['event-ambush'] = [-1];
      sounds['event-habitat-destroy'] = [-1];
      sounds['evolution-complete'] = [-1];
      sounds['evolution-gained'] = [-1];
      sounds['female-chat-fail'] = [1, 2, 3, 4, 5, 6, 7, 8, 9];
      sounds['female-choke'] = [1, 2, 3];
      sounds['female-crying-loud'] = [1, 2, 3];
      sounds['female-crying'] = [1, 2, 3, 4, 5, 6];
      sounds['female-die'] = [1, 2, 3];
      sounds['female-gasp'] = [1];
      sounds['female-grunt'] = [1];
      sounds['female-huh'] = [1];
      sounds['female-moan-loud'] = [1, 2, 3];
      sounds['female-moan'] = [1, 2, 3];
      sounds['female-ouch'] = [1];
      sounds['female-scream'] = [1];
      sounds['female-what'] = [1];
      sounds['female-whu'] = [1];
      sounds['game-win'] = [-1];
      sounds['human-alert'] = [1];
      sounds['human-stop'] = [1];
      sounds['item-book'] = [-1];
      sounds['item-drop'] = [-1];
      sounds['item-fail'] = [-1];
      sounds['item-laptop'] = [-1];
      sounds['item-money'] = [-1];
      sounds['item-nutrients'] = [-1];
      sounds['item-paper'] = [-1];
      sounds['item-smartphone'] = [-1];
      sounds['male-chat-fail'] = [1, 2, 3, 4, 5, 6];
      sounds['male-choke'] = [1, 2, 3];
      sounds['male-crying-loud'] = [1, 2];
      sounds['male-crying'] = [1, 2, 3, 4, 5, 6];
      sounds['male-die'] = [1, 2, 3];
      sounds['male-gasp'] = [1];
      sounds['male-grunt'] = [1];
      sounds['male-huh'] = [1];
      sounds['male-moan-loud'] = [1, 2, 3];
      sounds['male-moan'] = [1, 2, 3];
      sounds['male-ouch'] = [1];
      sounds['male-scream'] = [1];
      sounds['male-what'] = [1];
      sounds['male-whu'] = [1];
      sounds['message-default'] = [-1];
      sounds['music-about'] = [-1];
      sounds['music-corp'] = [-1];
      sounds['music-menu'] = [-1];
      sounds['music-menu2'] = [-1];
      sounds['music'] = [1, 2, 3, 4, 5];
      sounds['object-assimilation'] = [-1];
      sounds['object-elevator'] = [-1];
      sounds['object-growth'] = [-1];
      sounds['object-nutrients'] = [-1];
      sounds['object-preservator'] = [-1];
      sounds['object-sewers'] = [-1];
      sounds['object-stairs'] = [-1];
      sounds['organ-complete'] = [-1];
      sounds['parasite-attach'] = [1];
      sounds['parasite-detach'] = [1];
      sounds['parasite-die'] = [1, 2];
      sounds['parasite-invade'] = [-1];
      sounds['parasite-rebirth'] = [-1];
      sounds['pedia-new'] = [-1];
      sounds['region-habitat'] = [-1];
      sounds['region-ovum'] = [-1];
      sounds['team-notify'] = [-1];
      sounds['watcher-ambush'] = [-1];
      sounds['window-close'] = [-1];
      sounds['window-open'] = [-1];
#end

      // start playing music
      musicIdx = 1;
      music = SoundManager.createSound({
        id: 'music',
        url: 'sound/music' + musicIdx + '.mp3',
        volume: game.config.musicVolume,
        onfinish: onMusicEnd,
      });
      menuMusic = SoundManager.createSound({
        id: 'menuMusic',
        url: 'sound/music-menu2.mp3',
        volume: game.config.musicVolume,
        onfinish: function () {
          menuMusic.play();
        },
      });
      aboutMusic = SoundManager.createSound({
        id: 'aboutMusic',
        url: 'sound/music-about.mp3',
        volume: game.config.musicVolume,
        onfinish: function () {
          aboutMusic.play();
        },
      });
#end
      initDone = true;
    }

// after loading game
  public function loadPost()
    {
      onEnterArea();
    }

// after entering area
  public function onEnterArea()
    {
      var oldType = locationType;
      // check for area-specific music
      if (game.location == LOCATION_AREA)
        {
          if (game.area.info.type == 'corp')
            locationType = 'corp';
          else locationType = 'none';
        }
      else locationType = 'none';

      if (oldType != locationType)
        onMusicEnd();
    }

// after entering region mode (leaving area)
  public function onEnterRegion()
    {
      onEnterArea();
    }

// pick new music and queue
  function onMusicEnd()
    {
      var idx = 1;
      var x = sounds['music'];
      var files = [];
      for (f in x)
        if (f != musicIdx)
          files.push(f);
      idx = files[Std.random(files.length)];
      SoundManager.destroySound('music');
      musicIdx = idx;
      var url = 'sound/music' + musicIdx + '.mp3';
      if (locationType == 'corp')
        url = 'sound/music-corp.mp3';
      music = SoundManager.createSound({
        id: 'music',
        url: url,
        volume: game.config.musicVolume,
        onfinish: onMusicEnd,
      });
      music.play();
    }

// change ambience state
  public function setAmbient(st: _SoundAmbientLocation)
    {
#if !free
      if (st == ambientLocation)
        return;
      ambientLocation = st;

      game.debug('sound ambient ' + st);
      if (ambientNext.state == SOUND_FADEIN ||
          ambientNext.state == SOUND_FADEOUT)
        {
//          trace('fast stop next ' + ambientNext.sound.id);
          ambientNext.sound.setVolume(0);
          ambientNext.sound.stop();
          ambientNext.state = SOUND_STOPPED;
        }
      if (ambient.state == SOUND_PLAYING)
        ambient.state = SOUND_FADEOUT;
      else if (ambient.state != SOUND_STOPPED)
        {
//          trace('fast stop ' + ambient.sound.id);
          ambient.sound.setVolume(0);
          ambient.sound.stop();
          ambient.state = SOUND_STOPPED;
        }

      // start playing next with fade in
      var key = null;
      if (st == AMBIENT_CITY)
        key = 'ambient-city';
      else if (st == AMBIENT_REGION)
        key = 'ambient-region';
      else if (st == AMBIENT_WILDERNESS)
        key = 'ambient-wilderness';
      else if (st == AMBIENT_HABITAT)
        key = 'ambient-habitat';
      else if (st == AMBIENT_MILITARY)
        key = 'ambient-military';
      else if (st == AMBIENT_FACILITY)
        key = 'ambient-facility';
      else if (st == AMBIENT_CORP)
        key = 'ambient-corp';
      else key = 'ambient-city';
      var res = sounds[key];
      if (res == null)
        {
          trace('No such sound: ' + key);
          return;
        }
      key += res[Std.random(res.length)];
      ambientNext.sound = SoundManager.createSound({
        id: key,
        url: 'sound/' + key + '.mp3',
        volume: 0,
        loops: 10000,
      });
      ambientNext.sound.play();
      ambientNext.state = SOUND_FADEIN;
      var tmp = ambientNext;
      ambientNext = ambient;
      ambient = tmp;
#end
    }

// tick function for ambient sounds playing
  function ambientTick(info: _SoundInfo)
    {
/*
      trace("tick " + info.id + ' ' + info.state + ' ' +
        (info.sound != null ? info.sound.url : '-') + ' ' +
        (info.sound != null ? info.sound.volume : 0));
*/
      if (info.state == SOUND_FADEIN)
        {
          info.sound.setVolume(info.sound.volume + 1);
          if (info.sound.volume < game.config.ambientVolume)
            return;
          info.state = SOUND_PLAYING;
          info.sound.setVolume(info.sound.volume + 1);
        }
      else if (info.state == SOUND_FADEOUT)
        {
          info.sound.setVolume(info.sound.volume - 1);
          if (info.sound.volume > 0)
            return;
          info.state = SOUND_STOPPED;
          info.sound.setVolume(0);
          info.sound.stop();
          info.sound.setVolume(info.sound.volume + 1);
        }
    }

// play given sound from the library
// add random delay
  public function play(key: String, ?opts: _SoundOptions = null)
    {
      if (opts == null)
        opts = {
          delay: 0,
          canDelay: false,
          always: true,
        };
      if (opts.canDelay)
        Browser.window.setTimeout(playNow.bind(key, opts),
          Std.random(100));
      else if (opts.delay > 0)
        Browser.window.setTimeout(playNow.bind(key, opts),
          opts.delay);
      else playNow(key, opts);
    }

// play given sound from the library
  function playNow(key: String, opts: _SoundOptions)
    {
#if !free
      var res = sounds[key];
      if (res == null)
        {
          game.log('Sound [' + key + '] not found.');
          return;
        }
      if (res[0] != -1)
        key += res[Std.random(res.length)];
      if (!opts.always && haxe.Timer.stamp() - lastPlayedTS[key] < 1)
        {
//          trace('Skipping ' + key);
          return;
        }
      lastPlayedTS[key] = haxe.Timer.stamp();
      var volume = game.config.effectsVolume;
      if (opts.x != null && opts.y != null)
        {
          var dist = game.playerArea.distance(opts.x, opts.y);
          var radius = game.player.vars.listenRadius;// / 2;
          if (dist < radius)
            volume = Std.int(volume * (radius - dist) / radius);
          else volume = Std.int(volume * 0.1); // make silent instead?
        }
      var id = key + '|' + Std.random(4); // make it so sounds can repeat
      if (game.player.vars.debugSoundEnabled)
        game.debug('Playing sound ' + id + ' (opts: ' + opts + '), vol:' + volume + ' (of ' + game.config.effectsVolume + ')');
      SoundManager.destroySound(id); // clear previous sound
      var sound = SoundManager.createSound({
        id: id,
        url: 'sound/' + key + '.mp3',
        volume: volume,
      });
      sound.play();
#end
    }

/**
  
// temporarily pause all sounds
  public function pause()
    {
#if !free
      if (music != null)
        music.stop();
      stopAmbient();
#end
    }


// resume sound playing
  public function resume()
    {
#if !free
      if (music != null)
        {
          music.stop();
          music = sounds['music' + musicIdx].play(false, 0.01);
          music.onEnd = onMusicEnd;
          music.fadeTo(game.config.musicVolume / 100.0, 1);
        }
      var old = ambientLocation;
      ambientLocation = AMBIENT_NONE;
      setAmbient(old);
#end
    }
**/

#if !free
// music volume changed from options
  public inline function musicVolumeChanged()
    {
      music.setVolume(game.config.musicVolume);
      menuMusic.setVolume(game.config.musicVolume);
      aboutMusic.setVolume(game.config.musicVolume);
    }


// ambient volume changed from options
  public inline function ambientVolumeChanged()
    {
      if (ambient.sound != null &&
          ambient.state == SOUND_PLAYING)
        ambient.sound.setVolume(game.config.ambientVolume);
      if (ambientNext.sound != null &&
          ambientNext.state == SOUND_PLAYING)
        ambientNext.sound.setVolume(game.config.ambientVolume);
    }
#end
}

// js sound library
//@:jsRequire('soundManager')
extern class SoundManager
{
  static function setup(opts: Dynamic): Void;

  @:overload(function(id: String, url: String): SMSound {})
  static function createSound(opts: SMSoundOptions): SMSound;

  static function stop(id: String): Void;
  static function play(id: String, ?options: SoundPlayOptions): Dynamic;
  static function togglePause(id: Dynamic): Void;
  static function destroySound(id: String): Void;
  static function stopAll(): Void;

//  @:overload(function(id: String, vol: Int): Dynamic {})
//  static function setVolume(vol: Int): Void;
}

typedef SoundPlayOptions = {
  @:optional var volume: Int;
  @:optional var onfinish: Void -> Void; // callback function for "sound finished playing"
  @:optional var whileplaying: Void -> Void; // callback during play (position update)
}

typedef SMSoundOptions = {
  @:optional var id: String;
  @:optional var loops: Int;
  var url: String;
  @:optional var volume: Int; // self-explanatory. 0-100, the latter being the max.
  @:optional var onfinish: Void -> Void; // callback function for "sound finished playing"
  @:optional var whileplaying: Void -> Void; // callback during play (position update)
/**
  @:optional var autoLoad: false; // enable automatic loading (otherwise .load() will call with .play())
  @:optional var autoPlay: false; // enable playing of file ASAP (much faster if "stream" is true)
  @:optional var from: null; // position to start playback within a sound (msec), see demo
  @:optional var loops: 1; // number of times to play the sound. Related: looping (API demo)
  @:optional var multiShot: true; // let sounds "restart" or "chorus" when played multiple times..
  @:optional var multiShotEvents: false; // allow events (onfinish()) to fire for each shot, if supported.
  @:optional var onid3: null; // callback function for "ID3 data is added/available"
  @:optional var onload: null; // callback function for "load finished"
  @:optional var onstop: null; // callback for "user stop"
  @:optional var onpause: null; // callback for "pause"
  @:optional var onplay: null; // callback for "play" start
  @:optional var onresume: null; // callback for "resume" (pause toggle)
  @:optional var position: null; // offset (milliseconds) to seek to within downloaded sound.
  @:optional var pan: 0; // "pan" settings, left-to-right, -100 to 100
  @:optional var stream: true; // allows playing before entire file has loaded (recommended)
  @:optional var to: null; // position to end playback within a sound (msec), see demo
  @:optional var type: null; // MIME-like hint for canPlay() tests, eg. 'audio/mp3'
  @:optional var usePolicyFile: false; // enable crossdomain.xml request for remote domains (for ID3/waveform access)
  @:optional var whileloading: null; // callback function for updating progress (X of Y bytes received)
**/
}

typedef SMSound = {
  var id: String;
  var url: String;
  var volume(default, null): Int;
  var paused(default, null): Bool;
  var muted(default, null): Bool;
  var playState: Int; // 0 - stopped, 1 - playing
  public function setVolume(vol: Int): Void;
  public function stop(): Void;
  public function play(): Void;
  public function mute(): Void;
  public function unmute(): Void;
  public function pause(): Void;
  public function resume(): Void;

  @:optional var whileplaying: Void -> Void; // callback during play (position update)
/**
destruct()
load()
clearOnPosition()
onPosition()
setPan()
setPosition()
toggleMute()
togglePause()
unload()
**/
  
}

typedef _SoundInfo = {
  var id: String;
  var sound: SMSound;
  var state: _SoundAmbientState;
}

// sound ambience state
enum _SoundAmbientLocation
{
  AMBIENT_NONE;
  AMBIENT_CITY;
  AMBIENT_REGION;
  AMBIENT_WILDERNESS;
  AMBIENT_MILITARY;
  AMBIENT_FACILITY;
  AMBIENT_HABITAT;
  AMBIENT_CORP;
}

enum _SoundAmbientState
{
  SOUND_STOPPED;
  SOUND_FADEIN;
  SOUND_PLAYING;
  SOUND_FADEOUT;
}

