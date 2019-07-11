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
  var sounds: Map<String, Sound>;

  public function new(s: GameScene)
    {
      scene = s;
      sounds = new Map();

      // ogg for HL, mp3 for web
      var ext = (Sound.supportedFormat(Mp3) ? 'mp3' : 'ogg');

      var res = Res.load('sound/music3.' + ext).toSound();
      music = res.play(true, 0.3);

      var res = Res.load('sound/city1.' + ext).toSound();
      ambient = res.play(true, 0.3);

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
      files.add('parasite_die1');
      files.add('parasite_die2');
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
    }


// temporarily pause all sounds
  public function pause()
    {
      trace('pause');
      music.fadeTo(0.01, 0.5);
      ambient.fadeTo(0.01, 0.5);
    }


// resume sound playing
  public function resume()
    {
      trace('resume');
      music.fadeTo(0.3, 0.5);
      ambient.fadeTo(0.3, 0.5);
    }
}
