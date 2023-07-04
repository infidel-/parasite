// game console

package game;

import ai.*;
import const.*;
import objects.EventObject;

class ConsoleGame
{
  public var game: Game;


  public function new(g: Game)
    {
      game = g;
    }


// run console command
  public function run(cmd: String)
    {
      cmd = StringTools.trim(cmd);
      if (cmd == '')
        return;

//      log('Console command: ' + cmd);
      var arr = cmd.split(' ');
      var char0 = cmd.charAt(0);

#if mydebug
      // XXX add commands
      if (char0 == 'a')
        addCommand(cmd, arr);

      // XXX config commands
      else
#end
        if (char0 == 'c')
        {
          // XXX config|cfg <option> <value>
          if (arr[0] == 'config' || arr[0] == 'cfg')
            configOptionCommand(arr);
          // XXX chat|ch<stage>
          else if (arr[0].length >= 2 && arr[0].substr(0, 2) == 'ch')
            chatCommand(arr);
        }

      // XXX debug commands
      else if (char0 == 'd')
        debugCommand(cmd);

#if mydebug
      // XXX go commands
      else if (char0 == 'g')
        {
          if (cmd == 'god')
            {
              setVariableCommand(['set', 'player.godmode', '1' ]);
            }
          else goCommand(cmd);
        }
#end

      // XXX help
      else if (char0 == 'h')
        {
#if mydebug
          log('Available commands: ' +
            // add
            'ae - add effect, ' +
            'ai - add item, ' +
            'ao - add organ, ' +
            'as - add skill, ' +
            'at - add trait, ' +
            'cfg|config,<br/>' +
            'ch|chat - set chat stage' +
            'ddemo - debug: finish demo, ' +
            'dg - debug: graphics info, ' +
            'dthrow - debug: throw exception, ' +
            'dalert - debug: show alert, ' +
            'dleave - debug: leave area, ' +
            // go
            'ga - go and enter area, ' +
            'ge - go event location, ' +
            'gg - go x,y (region or area mode),<br/>' +
            'god - enable godmode, ' +
            // info
            'ie - timeline info (trace), ' +
            'ii - improvements info (trace),<br/>' +
            // learn
            'lc - learn random clues, ' +
            'le - learn about event, ' +
            'load - load game, ' +
            'lia - learn all improvements, ' +
            'li - learn improvement, ' +
            'lr - learn region map, ' +
            'lt - learn all timeline,<br/>' +
            //
            'oa - organ action,<br/>' +
            'snd - play sound, r/restart, ' +
            's - set player stage, ' +
            'spa - spawn ai, ' +
            'save - save game, ' +
            'set - set game variable, ' +
            'quit.');
#else
          log('Available commands: cfg, config, ' +
            'dg - debug: graphics info, ' +
            'dai - debug: ai info, ' +
            'ds - debug: enable sound info, ' +
            'load - load game, ' +
            'restart, ' +
            'save - save game, ' +
            'quit.');
#end
        }

#if mydebug
      // XXX info commands
      else if (char0 == 'i')
        infoCommand(cmd);

      // XXX learn commands
      else if (char0 == 'l')
        {
          // XXX load game
          if (arr[0] == 'load' || arr[0] == 'lo')
            game.load(1);

          else learnCommand(cmd);
        }
#end

      // XXX restart
      else if (char0 == 'r')
        {
//          if (arr[0] == 'restart')
            game.restart();
        }

      // XXX set commands
      else if (char0 == 's')
        {
          // XXX save game
          if (arr[0] == 'save' || arr[0] == 'sav' || arr[0] == 'sa')
            game.save(1);

#if mydebug
          // XXX set <variable> <value>
          else if (arr[0] == 'set')
            setVariableCommand(arr);

          // XXX snd <file>
          else if (arr[0] == 'snd')
            playSoundCommand(arr);

          // XXX spa <ai type>
          else if (arr[0] == 'spa')
            spawnAICommand(arr);

          else setCommand(cmd);
#end
        }

      // XXX organ action
      else if (char0 == 'o' && cmd.substr(0, 2) == 'oa')
        {
          if (cmd.length < 3)
            {
              log('Usage: oa[improvement index] [?level = max]');
              return;
            }

          if (game.player.state != PLR_STATE_HOST)
            {
              log('Need to have a host.');
              return;
            }

          var cmd2 = cmd.substr(2);
          var tmp = cmd2.split(' ');
          var idx = Std.parseInt(tmp[0]);
          var lvl = (tmp.length < 2 ? -1 : Std.parseInt(tmp[1]));
          var imp = EvolutionConst.improvements[idx];
          if (imp == null)
            {
              log('Improvement [' + idx + '] not found.');
              return;
            }
          if (lvl == -1 || lvl > imp.maxLevel)
            lvl = imp.maxLevel;

          if (imp.organ == null)
            {
              log('Improvement [' + idx + '] has no organ.');
              return;
            }

          if (imp.organ.onAction == null)
            {
              log('Improvement [' + idx + '] has no action.');
              return;
            }

          // give organ
          game.player.evolutionManager.addImprov(imp.id, lvl);
          game.player.host.organs.action('set.' + imp.id);
          game.player.host.organs.debugCompleteCurrent();

          imp.organ.onAction(game, game.player);
        }

      // XXX quit game
      else if (char0 == 'q')
// exit game
#if electron
        electron.renderer.IpcRenderer.invoke('quit');
#else
        Sys.exit(0);
#end

      game.updateHUD(); // update HUD state
      if (game.location == LOCATION_AREA)
        {
          game.scene.updateCamera();
          game.area.updateVisibility();
        }
    }

#if mydebug
// chat<stage>
// chat
  function chatCommand(arr: Array<String>)
    {
      var cmd = arr[0];
      if (cmd == 'chat' || cmd == 'ch')
        {
          log(';ch1 - affinity + skills<br/>' +
            ';ch2 - stage 1 + host high consent<br/>' +
            ';ch3 - stage 1 + host max consent<br/>'
          );
          return;
        }
      var stage = 0;
      if (StringTools.startsWith(cmd, 'chat'))
        stage = Std.parseInt(cmd.substr(4));
      else if (StringTools.startsWith(cmd, 'ch'))
        stage = Std.parseInt(cmd.substr(2));
      
      switch (stage)
        {
          case 1:
            chatStage1();
          case 2:
            chatStage1();
            game.player.host.chat.consent = 99;
          case 3:
            chatStage1();
            game.player.host.chat.consent = 100;
        }
    }

// stage 1: skills + affinity
  function chatStage1()
    {
      game.player.host.affinity = 80;
      addCommand('as', [ 'as', 'psychology', '80' ]);
      addCommand('as', [ 'as', 'coaxing', '80' ]);
      addCommand('as', [ 'as', 'coercion', '80' ]);
      addCommand('as', [ 'as', 'deception', '80' ]);
    }
#end

// config <option> <value>
// config
  function configOptionCommand(arr: Array<String>)
    {
      if (arr.length == 1)
        {
          game.config.dump(true);
          return;
        }

      if (arr.length < 3)
        {
          log('config|cfg [option] [value] - set config option');
          log('config|cfg - show config options');
          return;
        }

      var key = arr[1];
      var val = arr[2];
      game.config.set(key, val, true);
    }


// set <variable> <value>
// set
  function setVariableCommand(arr: Array<String>)
    {
      if (arr.length < 3)
        {
          log('set [variable] [value] - set game variable');
          log('set - show variables');
          log(
            'area.alertness, ' +
            'host., h. - energy (e), maxEnergy, health (h), maxHealth, ' +
            'group. - knownCount, priority, ' +
            'player. - godmode (p.god), habitats (p.hab), health (h), invisible (p.invis), los (p.los), ' +
            'team. - distance, level, size, timeout, timer');
          return;
        }

      var key = arr[1];
      var val = arr[2];
      var valInt = Std.parseInt(val);
      var valBool = (valInt > 0 || val == 'true');

      if (key == 'area.alertness')
        {
          if (game.location == LOCATION_AREA)
            game.area.alertness = valInt;
          else if (game.location == LOCATION_REGION)
            game.playerRegion.currentArea.alertness = valInt;
        }
      else if (key == 'host.energy' || key == 'h.energy' || key == 'h.e')
        {
          if (game.player.state == PLR_STATE_HOST)
            game.player.host.energy = valInt;
        }
      else if (key == 'host.maxEnergy' || key == 'h.maxEnergy')
        {
          if (game.player.state == PLR_STATE_HOST)
            game.player.host.maxEnergy = valInt;
        }
      else if (key == 'host.health' || key == 'h.health' || key == 'h.h')
        {
          if (game.player.state == PLR_STATE_HOST)
            game.player.host.health = valInt;
        }
      else if (key == 'host.maxHealth' || key == 'h.maxHealth')
        {
          if (game.player.state == PLR_STATE_HOST)
            game.player.host.maxHealth = valInt;
        }

      else if (key == 'group.knownCount')
        game.group.knownCount = valInt;
      else if (key == 'group.priority')
        game.group.priority = valInt;

      else if (key == 'player.habitats' || key == 'p.hab')
        game.player.vars.habitatsLeft = valInt;
      else if (key == 'player.health' || key == 'player.h' || key == 'p.h')
        {
          game.player.health = valInt;
        }
      else if (key == 'player.godmode' || key == 'p.god')
        game.player.vars.godmodeEnabled = valBool;
      else if (key == 'player.invisible' || key == 'p.invis')
        game.player.vars.invisibilityEnabled = valBool;
      else if (key == 'player.los' || key == 'p.los')
        {
          game.player.vars.losEnabled = valBool;
          if (game.location == LOCATION_AREA)
            game.area.updateVisibility();
        }

      else if (key == 'team.distance')
        {
          if (game.group.team != null)
            game.group.team.distance = valInt;
        }
      else if (key == 'team.level')
        {
          if (game.group.team != null)
            game.group.team.level = valInt;
        }
      else if (key == 'team.size')
        {
          if (game.group.team != null)
            game.group.team.size = valInt;
        }
      else if (key == 'team.timeout')
        game.group.teamTimeout = valInt;
      else if (key == 'team.timer')
        {
          if (game.group.team != null)
            game.group.team.timer = valInt;
        }
      else
        {
          game.log('Variable [' + key + '] not found.');
          return;
        }
      game.log('Set variable [' + key + '] to ' + val + '.');
    }

// spa <ai type>
// spa
  function spawnAICommand(arr: Array<String>)
    {
      if (arr.length < 2)
        {
          log('spa [ai type] - spawn AI');
          var buf = new StringBuf();
          log('spa - show AI types');
          log('AI types: ' + AreaGame.aiTypes.join(', '));
          return;
        }
      if (game.location != LOCATION_AREA)
        {
          log('Not in area.');
          return;
        }
      var type = arr[1];
      try {
        game.area.spawnAI(type, game.playerArea.x, game.playerArea.y);
      } catch (e: Dynamic)
        {
          log(e);
        }
    }


// snd <file>
// snd
  function playSoundCommand(arr: Array<String>)
    {
      if (arr.length < 2)
        {
          log('snd [file] - play sound file (no extension)');
          log('snd - show sound files');
          var list = new Array();
          for (s in @:privateAccess game.scene.sounds.sounds.keys())
            list.push(s);
          list.sort(function (a: String, b: String)
            {
              if (a > b)
                return 1;
              else if (a < b)
                return -1;
              return 0;
            });
          game.log(list.join(', '));

          return;
        }

      game.scene.sounds.play(arr[1]);
    }


// add commands
  function addCommand(cmd: String, arr: Array<String>)
    {
      // XXX [ae] add random effect
      if (cmd.charAt(1) == 'e')
        {
          if (game.player.state != PLR_STATE_HOST)
            {
              log('Not on host.');
              return;
            }
          var rnd = Std.random(100);
          var t: _AIEffectType = EFFECT_PANIC;
          if (rnd < 30)
            t = EFFECT_PARALYSIS;
          else if (rnd < 60)
            t = EFFECT_SLIME;
          game.player.host.onEffect({
            type: t,
            points: 10,
            isTimer: true
          });
          log('Added effect: ' + t);
        }

      // XXX [ai pistol] add item X
      else if (cmd.charAt(1) == 'i')
        {
          if (arr.length < 2)
            {
              var buf = new StringBuf();
              buf.add('Usage: ai [item]<br/>');
              buf.add('Items: ');
              for (info in ItemsConst.items)
                buf.add(info.id + ', ');
              var s = buf.toString();
              s = s.substr(0, s.length - 2) + '.';
              log(s);
              return;
            }

          var id = arr[1];
          if (game.player.state != PLR_STATE_HOST)
            return;

          try {
            game.player.host.inventory.addID(id);
          } catch (e) {
            game.log(e + '');
            return;
          }
          game.log('Item added.');
        }

      // XXX [ao10] add organ X
      else if (cmd.charAt(1) == 'o')
        {
          if (cmd == 'ao')
            {
              log('Usage: ao[index]');
              var s = new StringBuf();
              for (i in 0...EvolutionConst.improvements.length)
                {
                  var imp = EvolutionConst.improvements[i];
                  if (imp.organ == null)
                    continue;

                  s.add(i + ': ' + imp.organ.name + ', ' + imp.id + ', ');
                }
              log(Const.small(s.toString()));
              return;
            }
          if (game.player.state != PLR_STATE_HOST)
            return;

          var idx = Std.parseInt(StringTools.trim(cmd.substr(2)));
          var imp = EvolutionConst.improvements[idx];
          if (imp == null)
            {
              log('Improvement [' + idx + '] not found.');
              return;
            }

          game.player.evolutionManager.addImprov(imp.id, imp.maxLevel);
          game.player.host.organs.action('set.' + imp.id);
          game.player.host.organs.debugCompleteCurrent();
        }

      // XXX [as computer 10] add skill X Y
      else if (cmd.charAt(1) == 's')
        {
          if (arr.length < 3)
            {
              var buf = new StringBuf();
              log('Usage: as [skill] [amount]');
              buf.add('Skills: ');
              for (info in SkillsConst.skills)
                {
                  var tmp = '' + info.id;
                  tmp = tmp.substr(tmp.indexOf('_') + 1);
                  tmp = tmp.toLowerCase();

                  buf.add(tmp + ', ');
                }
              var s = buf.toString();
              s = s.substr(0, s.length - 2) + '.';
              log(s);
              return;
            }

          var id = arr[1].toUpperCase();
          var amount = Std.parseInt(arr[2]);
          var skill = null;
          try {
              skill = Type.createEnum(_Skill, 'SKILL_' + id);
            }
          catch (e: Dynamic)
            {
              skill = null;
              trace(e);
            }

          if (skill == null)
            try {
                skill = Type.createEnum(_Skill, 'KNOW_' + id);
              }
            catch (e: Dynamic)
              {
                skill = null;
                trace(e);
              }

          if (skill == null)
            {
              game.log('No such skill or knowledge found.');
              return;
            }

          game.player.skills.addID(skill, amount);
          game.log('Skill/knowledge added.');
        }

      // XXX [at] add random trait
      else if (cmd.charAt(1) == 't')
        {
          if (game.player.state != PLR_STATE_HOST)
            {
              log('Not on host.');
              return;
            }
          var rnd = Std.random(100);
          var t: _AITraitType = TRAIT_DRUG_ADDICT;
          if (rnd < 50)
            t = TRAIT_ASSIMILATED;
          game.player.host.addTrait(t);
          log('Added trait: ' + t);
        }

    }

// debug commands
  function debugCommand(cmd: String)
    {
      // XXX dg - show graphics objects info
      if (cmd.charAt(1) == 'g')
        {
          log('Scene children objects: ' + game.scene.numChildren +
            '<br/>Scene total objects: ' + game.scene.getObjectsCount());
        }
      // XXX dai - show ai view/hear info
      else if (cmd == 'dai')
        {
          log(
            'Window resolution: ' +
            game.scene.win.width + 'x' + game.scene.win.height +
            ', scale: ' + (game.config.mapScale * 100) +
            '%, tile resolution: ' +
            Std.int(game.scene.win.width / Const.TILE_SIZE) + 'x' +
            Std.int(game.scene.win.height / Const.TILE_SIZE) +
            ', AI view distance: ' + ai.AI.VIEW_DISTANCE +
            ', AI hear distance: ' + ai.AI.HEAR_DISTANCE +
            '<br>Current area, max AI: ' + game.area.getMaxAI() +
            ' = [common AI: ' + game.area.info.commonAI +
            ' * pow(' +
            'emptyScreenCells: ' + game.scene.area.emptyScreenCells +
            ' / AREA_AI_CELLS: ' + WorldConst.AREA_AI_CELLS + ', ' +
            game.area.getMaxAICoef() + ')]'
          );
        }
      // XXX ds - enable debug sound info
      else if (cmd == 'ds')
        {
          game.player.vars.debugSoundEnabled = !game.player.vars.debugSoundEnabled;
          game.debug('Sound debug toggled.');
        }
#if mydebug
      else if (cmd == 'dalert')
        game.log('This is a test alert message.', COLOR_ALERT);
      else if (cmd == 'ddemo')
        {
          game.message('Thank you for playing the demo! You can restart the game now and play it to this point again but to progress further you will need to buy the full game.');
          game.ui.event({
            type: UIEVENT_FINISH,
            state: null,
            obj: {
              result: 'lose',
              condition: 'demo',
            }
          });
        }
      else if (cmd == 'dleave')
        {
          if (game.location != LOCATION_AREA)
            game.log('Not in area.');
          else game.setLocation(LOCATION_REGION);
        }
      else if (cmd == 'dthrow')
        throw 'test exception';
#end
    }

// go commands
  function goCommand(cmd: String)
    {
      // XXX [ga10 10] go to area and enter it
      if (cmd.charAt(1) == 'a')
        {
          if (cmd.length < 3)
            {
              log('Usage: ga[x] [y]');
              return;
            }
          var tmp = cmd.substr(2).split(' ');
          if (tmp.length < 2 || tmp.length > 2)
            {
              log('wrong format');
              return;
            }

          var x = Std.parseInt(tmp[0]);
          var y = Std.parseInt(tmp[1]);
          var area = game.region.getXY(x, y);
          if (area == null)
            {
              log('wrong location');
              return;
            }

          log('Teleporting to area (' + x + ',' + y + ').');
          game.player.teleport(area);
        }

      // XXX [ge10] go to event X location
      else if (cmd.charAt(1) == 'e')
        {
          if (cmd.length < 3)
            {
              log('Usage: ge[event index]');
              return;
            }
          var idx = Std.parseInt(cmd.substr(2));
          var event = game.timeline.getEventByIndex(idx);
          if (event == null)
            {
              log('Event ' + idx + ' not found in the timeline.');
              return;
            }

          if (event.location == null)
            {
              log('Event ' + idx + ' has no location.');
              return;
            }

          log('Teleporting to event ' + idx + ' location.');

          var area = event.location.area;
          game.ui.state = UISTATE_DEFAULT;
          game.player.teleport(area);
        }

      // XXX [gg10 10] go to location x,y at current location
      else if (cmd.charAt(1) == 'g')
        {
          if (cmd.length < 3)
            {
              log('Usage: gg[x] [y]');
              return;
            }
          var tmp = cmd.substr(2).split(' ');
          if (tmp.length < 2 || tmp.length > 2)
            {
              log('wrong format');
              return;
            }

          var x = Std.parseInt(tmp[0]);
          var y = Std.parseInt(tmp[1]);

          log('Teleporting to location (' + x + ',' + y + ').');

          if (game.location == LOCATION_AREA)
            game.playerArea.moveTo(x, y);
          else game.playerRegion.moveTo(x, y, false);
        }
    }


// info commands
  function infoCommand(cmd: String)
    {
      // XXX [ie] events info
      if (cmd.charAt(1) == 'e')
        {
          for (ev in game.timeline)
            Const.p('' + ev);
        }

      // XXX [ii] improvements info
      else if (cmd.charAt(1) == 'i')
        {
          var s = new StringBuf();
          for (i in 0...EvolutionConst.improvements.length)
            {
              var imp = EvolutionConst.improvements[i];

              s.add(i + ': ' + imp.name + ', ' + imp.id +
                ' (' + ('' + imp.type).substr(5) + ')');
              if (imp.organ != null)
                s.add(' [' + imp.organ.name + ']');
              if (i < EvolutionConst.improvements.length - 1)
                s.add(', ');
            }
          log(Const.small(s.toString()));
        }
    }


// learn commands
  function learnCommand(cmd: String)
    {
      // XXX [lc] learn random clues
      if (cmd.charAt(1) == 'c')
        {
          game.goals.receive(GOAL_LEARN_CLUE);
          game.goals.complete(GOAL_LEARN_CLUE);
          for (i in 0...5)
            game.timeline.learnClues(game.timeline.getRandomEvent(), true);
        }
      // XXX [le10] learn everything about event X
      else if (cmd.charAt(1) == 'e')
        {
          if (cmd.length < 3)
            {
              log('Usage: le[event index]');
              return;
            }
          var idx = Std.parseInt(cmd.substr(2));
          var event = game.timeline.getEventByIndex(idx);
          if (event == null)
            {
              log('Event [' + idx + '] not found in the timeline.');
              return;
            }

          while (!event.notesKnown())
            event.learnNote();
          event.learnLocation();
        }

      // XXX [lia] learn all improvements
      else if (cmd.charAt(1) == 'i' && cmd.charAt(2) == 'a')
        {
          var level = 3;
          if (cmd.length > 2)
            level = Std.parseInt(cmd.substr(3));
          for (imp in EvolutionConst.improvements)
            game.player.evolutionManager.addImprov(imp.id, level);
          log('All improvements learned.');

          game.player.evolutionManager.state = 2;
        }

      // XXX [li10 1] learn improvement X at level Y
      else if (cmd.charAt(1) == 'i')
        {
          if (cmd.length < 3)
            {
              log('Usage: li[improvement index] [?level = max]');
              return;
            }
          var cmd2 = cmd.substr(2);
          var tmp = cmd2.split(' ');
          var idx = Std.parseInt(tmp[0]);
          var lvl = (tmp.length < 2 ? -1 : Std.parseInt(tmp[1]));
          var imp = EvolutionConst.improvements[idx];
          if (imp == null)
            {
              log('Improvement [' + idx + '] not found.');
              return;
            }
          if (lvl == -1 || lvl > imp.maxLevel)
            lvl = imp.maxLevel;

          game.player.evolutionManager.addImprov(imp.id, lvl);
          log('Learned ' + imp.name + ' ' + lvl);
        }

      // XXX [lr] learn region map
      else if (cmd.charAt(1) == 'r')
        {
          for (a in game.region)
            a.isKnown = true;
          if (game.location == LOCATION_REGION)
            game.scene.region.update();
          log('Region map opened.');
        }

      // XXX [lt] learn all timeline
      else if (cmd.charAt(1) == 't')
        {
          game.log('Timeline opened.');
          for (e in game.timeline)
            {
              e.locationKnown = true;
              for (n in e.notes)
                n.isKnown = true;

              for (npc in e.npc)
                {
                  npc.nameKnown = true;
                  npc.jobKnown = true;
                  npc.areaKnown = true;
                  npc.statusKnown = true;
                }

//              e.learnLocation();
            }
          game.player.vars.npcEnabled = true;
          game.player.vars.searchEnabled = true;

          game.timeline.update(); // update event numbering
        }
    }


// set/stage commands
  function setCommand(cmd: String)
    {
      // no arguments, show available
      if (cmd == 's')
        {
          log(
            ';s1 - set player stage 1 (human civilian host, tutorial done)<br/>' +
            ';s11 - set player stage 1.1 (stage 1 + group knowledge)<br/>' +
            ';s12 - set player stage 1.2 (stage 1.1 + ambush)<br/>' +
            ';s2 - set player stage 2 (stage 1 + microhabitat)<br/>' +
            ';s21 - set player stage 2.1 (stage 2 + camo layer, computer use)<br/>' +
            ';s22 - set player stage 2.2 (stage 2.1 + biomineral)<br/>' +
            ';s23 - set player stage 2.3 (stage 2.2 + assimilation)<br/>' +
            ';s24 - set player stage 2.4 (stage 2.1 + group knowledge)<br/>' +
            ';s25 - set player stage 2.5 (stage 2 + ambush)<br/>' +
            ';s3 - set player stage 3 (stage 2.3 + spaceship)'
            );
          return;
        }

      var stage = Std.parseInt(cmd.substr(1));

      // XXX [s1] set stage X
      if (stage > 0)
        {
          game.importantMessagesEnabled = false;

          // stage 1: civ host, tutorial done
          if (stage == 1)
            {
              stage1();
            }

          // stage 1.1: stage 1 + group knowledge
          else if (stage == 11)
            {
              stage1();
              stage11();
            }

          // stage 1.1: stage 1 + group knowledge
          else if (stage == 12)
            {
              stage1();
              stage11();
              stage12();
            }

          // stage 2: civ host, microhabitat, timeline open
          else if (stage == 2)
            {
              stage1();
              stage2();
            }

          // stage 2.1: 2 + camo, dopamine, computer
          else if (stage == 21)
            {
              stage1();
              stage2();
              stage21();
            }

          // stage 2.2: 2.1 + biomineral
          else if (stage == 22)
            {
              stage1();
              stage2();
              stage21();
              stage22();
            }

          // stage 2.3: 2.2 + assimilation cavity
          else if (stage == 23)
            {
              stage1();
              stage2();
              stage21();
              stage22();
              stage23();
            }

          // stage 2.4: 2.1 + group knowledge
          else if (stage == 24)
            {
              stage1();
              stage2();
              stage21();
              stage24();
            }

          // stage 2.5: 2 + 1.2 (ambush)
          else if (stage == 25)
            {
              stage1();
              stage2();
              stage25();
            }

          // stage 3: 2.3 + timeline open until scenario goals
          else if (stage == 3)
            {
              stage1();
              stage2();
              stage21();
              stage22();
              stage23();
              stage3();
            }

          game.importantMessagesEnabled = true;
        }

      // XXX [sa] set area commands
      else if (cmd.charAt(1) == 'a')
        {
        }

      // fix for gui queue
      game.ui.closeWindow();
    }


// stage 1: civ host, tutorial done
  function stage1()
    {
      game.log('stage 1');
      // spawn AI, attach to it and invade
      var ai = game.area.spawnAI('civilian',
        game.playerArea.x, game.playerArea.y);
      ai.skills.addID(SKILL_COMPUTER, 10 + Std.random(20));
      game.playerArea.debugAttachAndInvadeAction(ai);
      game.player.hostControl = 100;

      // tutorial line
      game.goals.complete(GOAL_TUTORIAL_ALERT);
      game.goals.complete(GOAL_TUTORIAL_BODY);
      game.goals.complete(GOAL_TUTORIAL_BODY_SEWERS);
      game.goals.complete(GOAL_TUTORIAL_ENERGY);
      game.goals.complete(GOAL_TUTORIAL_AREA_ALERT);
      game.goals.complete(GOAL_INVADE_HOST);
      game.goals.complete(GOAL_INVADE_HUMAN);
      game.player.evolutionManager.addImprov(IMP_BRAIN_PROBE, 2);
      game.goals.complete(GOAL_EVOLVE_PROBE);
      var probeInfo = const.EvolutionConst.getInfo(IMP_BRAIN_PROBE);
      game.playerArea.action(probeInfo.action);
      game.goals.complete(GOAL_LEARN_ITEMS);
      game.playerArea.action(probeInfo.action);

      // society knowledge
      game.player.skills.increase(KNOW_SOCIETY, 1);
      game.player.skills.increase(KNOW_SOCIETY, 24);

      // starting improvements
      game.player.evolutionManager.difficulty = EASY;
      game.player.evolutionManager.giveStartingImprovements();
    }


// stage 1.1: stage 1 + group knowledge
  function stage11()
    {
      game.log('stage 1.1');
      var ai = game.player.host;
      ai.brainProbed = 0;
      game.group.knownCount = 1;

      if (game.scenarioStringID == 'alien')
        {
          // get a random live npc and tie it to the host
          var listEvents = [ 'parasiteRemoval', 'parasiteTransportation' ];
          for (id in listEvents)
            {
              var ev = game.timeline.getEvent(id);
              var npc = null;
              trace(ev.npc);
              for (n in ev.npc)
                if (!n.isDead)
                  {
                    npc = n;
                    break;
                  }
              // all npcs dead, try next event
              if (npc == null)
                continue;

              // link host to this npc
              npc.ai = ai;
              ai.eventID = ev.id;
              ai.npcID = npc.id;
              ai.isNPC = true;
              ai.entity.setNPC();

              break;
            }
        }
      else
        {
          // kill host from stage 1
          game.playerArea.leaveHostAction('default');
          ai.die();

          game.group.team = new Team(game);
          game.group.team.distance = 10;

          // spawn team member AI, attach to it and invade
          var ai = game.area.spawnAI('team',
            game.playerArea.x, game.playerArea.y);
          ai.isTeamMember = true;
          game.playerArea.debugAttachAndInvadeAction(ai);
          game.player.hostControl = 100;
        }
    }


// stage 1.2: stage 1.1 + ambush
  function stage12()
    {
      game.log('stage 1.2');
      game.group.team = new Team(game);
      game.group.team.distance = 0;
      game.group.team.level = 4;
      game.group.team.state = TEAM_AMBUSH;
      game.group.team.timer = 0;
    }


// stage 2: stage 1 + microhabitat, timeline open
  function stage2()
    {
      game.log('stage 2');
      game.player.evolutionManager.addImprov(IMP_ENERGY, 1);
      game.player.evolutionManager.addImprov(IMP_BRAIN_PROBE, 3);
      game.goals.complete(GOAL_EVOLVE_ORGAN);
      game.player.host.organs.action('set.IMP_ENERGY');
      game.player.host.organs.debugCompleteCurrent();

      // habitat
      game.player.evolutionManager.addImprov(IMP_MICROHABITAT, 1);
      game.goals.complete(GOAL_EVOLVE_MICROHABITAT);

      // learn and enter sewers
      game.playerArea.debugLearnObject('sewer_hatch');
      game.ui.state = UISTATE_DEFAULT;
      game.setLocation(LOCATION_REGION);

      game.playerRegion.action({
        id: 'createHabitat',
        type: ACTION_REGION,
        name: 'Create habitat',
        energy: 0
      });
//      game.goals.complete(GOAL_CREATE_HABITAT);
    }


// stage 2.1: stage 2 + camo, dopamine, computer
  function stage21()
    {
      // camo
      game.goals.receive(GOAL_EVOLVE_CAMO);
      game.goals.complete(GOAL_EVOLVE_CAMO);
      game.player.evolutionManager.addImprov(IMP_CAMO_LAYER, 2);
      game.player.host.organs.action('set.IMP_CAMO_LAYER');
      game.player.host.organs.debugCompleteCurrent();

      // dopamine
      game.goals.receive(GOAL_EVOLVE_DOPAMINE);
      game.goals.complete(GOAL_EVOLVE_DOPAMINE);
      game.player.evolutionManager.addImprov(IMP_DOPAMINE, 1);

      // computer and computer use
      game.player.host.inventory.addID('smartphone');
      game.player.addKnownItem('smartphone');
      game.player.host.inventory.addID('laptop');
      game.player.addKnownItem('laptop');
      game.player.host.skills.addID(SKILL_COMPUTER, 20 + Std.random(30));
      game.player.skills.addID(SKILL_COMPUTER, 30);

      // forward timeline
      if (game.scenarioStringID == 'alien')
        {
          game.goals.receive(GOAL_LEARN_CLUE);
          game.timeline.learnClues(game.timeline.getStartEvent(), true);
          game.timeline.getStartEvent().learnNPC();
          game.goals.complete(GOAL_LEARN_NPC);
        }
    }


// stage 2.2: stage 2.1 + biomineral
  function stage22()
    {
      // enter habitat
      game.playerRegion.action({
        id: 'enterHabitat',
        type: ACTION_REGION,
        name: 'Enter habitat',
        energy: 0
      });

      // biomineral
      game.player.evolutionManager.addImprov(IMP_BIOMINERAL, 2);
      game.player.host.organs.action('set.IMP_BIOMINERAL');
      game.player.host.organs.debugCompleteCurrent();

      // build biomineral
      var o = game.player.host.organs.get(IMP_BIOMINERAL);
      var a = o.info.action;
      a.obj = o;
      game.player.host.organs.areaAction(a);

      // spawn AI, attach to it and invade
      var ai = game.area.spawnAI('civilian',
        game.playerArea.x, game.playerArea.y);
      game.playerArea.debugAttachAndInvadeAction(ai);
      game.player.hostControl = 100;
    }


// stage 2.3: stage 2.2 + assimilation cavity
  function stage23()
    {
      // assimilation cavity
      game.player.evolutionManager.addImprov(IMP_ASSIMILATION, 1);
      game.player.host.organs.action('set.IMP_ASSIMILATION');
      game.player.host.organs.debugCompleteCurrent();

      // move right
      game.playerArea.moveBy(1, 0);

      // build assimilation cavity
      var o = game.player.host.organs.get(IMP_ASSIMILATION);
      var a = o.info.action;
      a.obj = o;
      game.player.host.organs.areaAction(a);

      // spawn AI, attach to it and invade
      var ai = game.area.spawnAI('civilian',
        game.playerArea.x, game.playerArea.y);
      game.playerArea.debugAttachAndInvadeAction(ai);
      game.player.hostControl = 100;

      // computer and computer use
      game.player.host.inventory.addID('smartphone');
      game.player.addKnownItem('smartphone');
      game.player.host.inventory.addID('laptop');
      game.player.addKnownItem('laptop');
      game.player.host.skills.addID(SKILL_COMPUTER, 20 + Std.random(30));
    }


// stage 2.4: stage 2.1 + group knowledge
  function stage24()
    {
      game.log('stage 2.4');
      game.setLocation(LOCATION_AREA);
      stage11();
    }

// stage 2.5: stage 2 + ambush
  function stage25()
    {
      // enter habitat
      game.playerRegion.action({
        id: 'enterHabitat',
        type: ACTION_REGION,
        name: 'Enter habitat',
        energy: 0
      });
      game.group.team = new Team(game);
      game.group.team.distance = 2;
      game.group.team.level = 4;
      game.group.team.state = TEAM_AMBUSH;
      game.group.team.timer = 0;
    }


// stage 3: stage 2.3 + timeline open until scenario goals
  function stage3()
    {
      if (game.scenarioStringID != 'alien')
        {
          log('Different scenario: ' + game.scenarioStringID + '.');
          return;
        }

      // assimilate current host
      game.player.host.addTrait(TRAIT_ASSIMILATED);

      // learn needed events
      for (idx in [ 12, 11, 8, 7 ])
        {
          var event = game.timeline.getEventByIndex(idx);
          while (!event.notesKnown())
            event.learnNote();
          event.learnLocation();
        }

      // go to the spaceship location
      var ev = game.timeline.getEvent('alienShipStudy');
      var area = ev.location.area;
      goCommand('ga' + area.x + ' ' + area.y);

      var obj = @:privateAccess scenario.GoalsAlienCrashLanding.getSpaceshipObject(game);
      goCommand('gg' + obj.x + ' ' + obj.y);
    }


// log function
  inline function log(s: String)
    {
      game.log(s, COLOR_DEBUG);
    }
}

