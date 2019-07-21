// sounds and music manager

import hxd.Res;
import hxd.res.Sound;
import hxd.snd.Channel;
import ai.AI;
import game._ItemInfo;
import const.*;

class SoundManager
{
  var scene: GameScene;
  var music: Channel;
  var ambient: Channel;
  var ambientNext: Channel;
  var ambientState: _SoundAmbientState;
  var ambientFade: Bool; // when true, ambient state is being switched
  var sounds: Map<String, Sound>;

  public function new(s: GameScene)
    {
      scene = s;
      sounds = new Map();
      ambient = null;
      ambientNext = null;
      ambientState = AMBIENT_NONE;
      ambientFade = false;
      music = null;

#if !free
      // ogg for HL, mp3 for web
      var ext = (Sound.supportedFormat(Mp3) ? 'mp3' : 'ogg');

      // browse all AI sound maps and pull sound names
      var filesMap = new Map();
      addSoundMap(filesMap, SoundConst.dog);
      addSoundMap(filesMap, SoundConst.civilian);
      addSoundMap(filesMap, SoundConst.police);
      addSoundMap(filesMap, SoundConst.soldier);
      addSoundMap(filesMap, SoundConst.agent);
      addSoundMap(filesMap, SoundConst.security);
      addSoundMap(filesMap, SoundConst.team);

      // add all item sounds
      addItemSounds(filesMap, ItemsConst.fists);
      addItemSounds(filesMap, ItemsConst.animal);
      for (item in ItemsConst.items)
        addItemSounds(filesMap, item);

      // load sounds
      var files = new List();
      for (f in SoundConst.misc)
        files.add(f);
      for (f in filesMap.keys())
        files.add(f);
      for (f in files)
        {
          var res = null;
          try {
            res = Res.load('sound/' + f + '.' + ext);
          }
          catch (e: Dynamic)
            {
              scene.game.debug('Cannot load file sound/' + f + '.' + ext + '.');
              continue;
            }

          sounds[f] = res.toSound();
        }

      // start playing music
      music = sounds['music1'].play(true, 0.3);
#end
    }


// change ambience state
  public function setAmbient(st: _SoundAmbientState)
    {
      if (st == ambientState)
        return;

      scene.game.debug('sound ambient ' + st);

      // currently in fade, just reset
      if (ambientFade)
        stopAmbient();

      // fade old to silence
      ambientFade = true;
      ambientState = st;
      if (ambient != null)
        ambient.fadeTo(0, 2, function () {
          ambientFade = false;
          ambient.stop();
          ambient = ambientNext;
        });

      // start playing next with fade in
      var key = null;
      if (st == AMBIENT_CITY)
        key = 'ambient_city1';
      else if (st == AMBIENT_REGION)
        key = 'ambient_region1';
      else if (st == AMBIENT_WILDERNESS)
        key = 'ambient_wilderness1';
      else if (st == AMBIENT_HABITAT)
        key = 'ambient_habitat1';
      else if (st == AMBIENT_MILITARY)
        key = 'ambient_military1';
      else if (st == AMBIENT_FACILITY)
        key = 'ambient_facility1';
      else key = 'ambient_city1';
      var res = sounds[key];
      if (res == null)
        {
          trace('No such sound: ' + key);
          return;
        }
      ambientNext = res.play(true, 0.01);
      ambientNext.fadeTo(0.3, 2);
      if (ambient == null) // first call or after reset
        {
          ambient = ambientNext;
          ambientFade = false;
        }
    }


// reset ambient sound state
  function stopAmbient()
    {
//          scene.game.debug('reset!');
      ambient.stop();
      ambientNext.stop();
      ambient = null;
      ambientNext = null;
      ambientFade = false;
    }


// add AI sound map
  function addSoundMap(files: Map<String, Int>,
      map: Map<String, Array<AISound>>)
    {
      for (arr in map)
        for (snd in arr)
          if (snd.files != null)
            for (f in snd.files)
              {
                files.set(f, 1);
                if (f.indexOf('male') == 0)
                  files.set('fe' + f, 1);
              }
    }


// add item sounds
  function addItemSounds(files: Map<String, Int>, item: _ItemInfo)
    {
      if (item.weapon == null || item.weapon.sounds == null)
        return;

      for (f in item.weapon.sounds)
        files.set(f, 1);
    }


// play given sound
  public function playSound(key: String, always: Bool)
    {
#if !free
      if (!sounds.exists(key))
        {
          scene.game.log('Sound [' + key + '] not found.');
          return;
        }

      // not important sounds are skipped if not enough time has passed
      if (!always && haxe.Timer.stamp() - sounds[key].lastPlay < 1)
        {
//          scene.game.debug('Skipping ' + key);
          return;
        }
      scene.game.debug('Playing sound ' + key);
      sounds[key].play(false, 0.5);
#end
    }


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
          music = sounds['music1'].play(true, 0.01);
          music.fadeTo(0.3, 1);
        }
      var old = ambientState;
      ambientState = AMBIENT_NONE;
      setAmbient(old);
#end
    }
}
