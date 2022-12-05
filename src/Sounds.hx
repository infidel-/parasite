// sounds and music manager
import ai.AI;
import game._ItemInfo;
import game.Game;
import const.*;
import js.node.Fs;
import js.Browser;

class Sounds
{
  var musicIdx: Int;
  var scene: GameScene;
  var game: Game;
  var sounds: Map<String, Array<Int>>;
  var lastPlayedTS: Map<String, Float>;
  var music: SMSound;
  var ambient: _SoundInfo; 
  var ambientNext: _SoundInfo;
  var ambientLocation: _SoundAmbientLocation;

  public function new(s: GameScene)
    {
      scene = s;
      lastPlayedTS = new Map();
      game = scene.game;
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
        if (game.ui.state == UISTATE_MAINMENU ||
            game.ui.state == UISTATE_OPTIONS ||
            game.ui.state == UISTATE_PEDIA)
          {
            if (music.playState == 1 && !music.paused)
              music.pause();
            if (ambient.state != SOUND_STOPPED && !ambient.sound.muted)
              ambient.sound.mute();
            if (ambientNext.state != SOUND_STOPPED && !ambientNext.sound.muted)
              ambientNext.sound.mute();
            return;
          }
        else
          {
            if (music.playState == 0)
              music.play();
            else if (music.paused)
              music.resume();
            if (ambient.state != SOUND_STOPPED && ambient.sound.muted)
              ambient.sound.unmute();
            if (ambientNext.state != SOUND_STOPPED && ambientNext.sound.muted)
              ambientNext.sound.unmute();
          }
        ambientTick(ambient);
        ambientTick(ambientNext);
      }, 15);
      ambientLocation = AMBIENT_NONE;
      music = null;
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

      // start playing music
      musicIdx = 1;
      music = SoundManager.createSound({
        id: 'music',
        url: 'sound/music' + musicIdx + '.mp3',
        volume: game.config.musicVolume,
        onfinish: onMusicEnd,
      });
#end
    }

// pick new music and queue
  function onMusicEnd()
    {
      var idx = 1;
#if electron
      var x = sounds['music'];
      var files = [];
      for (f in x)
        if (f != musicIdx)
          files.push(f);
      idx = files[Std.random(files.length)];
#end
      SoundManager.destroySound('music');
      musicIdx = idx;
      music = SoundManager.createSound({
        id: 'music',
        url: 'sound/music' + musicIdx + '.mp3',
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
          canDelay: false,
          always: true,
        };
      if (opts.canDelay)
        Browser.window.setTimeout(playNow.bind(key, opts),
          Std.random(100));
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
      var last = lastPlayedTS[key];
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
//      game.debug('Playing sound ' + id + ' (opts: ' + opts + '), vol:' + volume + ' (of ' + game.config.effectsVolume + ')');
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
    }


// ambient volume changed from options
  public inline function ambientVolumeChanged()
    {
      if (ambient.sound != null && ambient.state == SOUND_PLAYING)
        ambient.sound.setVolume(game.config.ambientVolume);
      if (ambientNext.sound != null && ambientNext.state == SOUND_PLAYING)
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
}

enum _SoundAmbientState
{
  SOUND_STOPPED;
  SOUND_FADEIN;
  SOUND_PLAYING;
  SOUND_FADEOUT;
}

