// game console helper

package console;

import const.*;
import const.EvolutionConst.ImprovInfo;
import game.*;
import haxe.Json;
#if electron
import js.node.Fs;
#end

class Console
{
  public var game: Game;
  var history: Array<String>;
  var addConsole: Add;
  var stageConsole: Stage;


  public function new(g: Game)
    {
      game = g;
      history = [];
      loadHistory();
      addConsole = new Add(this);
      stageConsole = new Stage(this);
    }


// run console command
  public function run(cmd: String)
    {
      cmd = StringTools.trim(cmd);
      if (cmd == '')
        return;

      recordHistory(cmd);

//      log('Console command: ' + cmd);
      var arr = cmd.split(' ');
      var char0 = cmd.charAt(0);

#if mydebug
      // XXX add commands
      if (char0 == 'a')
        addConsole.run(cmd);

      // XXX config commands
      else
#end
        if (char0 == 'c')
        {
          // XXX config|cfg <option> <value>
          if (arr[0] == 'config' || arr[0] == 'cfg')
            configOptionCommand(arr);
#if mydebug
          // XXX chat|ch<stage>
          else if (arr[0].length >= 2 && arr[0].substr(0, 2) == 'ch')
            chatCommand(arr);
#end
        }

      // XXX debug commands
      else if (char0 == 'd')
        debugCommand(cmd);

#if mydebug
      // XXX go, gc, god commands
      else if (char0 == 'g')
        {
          if (cmd == 'god')
            {
              setVariableCommand(['set', 'player.godmode', '1' ]);
            }
          //
          else if (cmd == 'gc')
            completeGoals();
          else goCommand(cmd);
        }
#end

      // XXX help
      else if (char0 == 'h')
        {
#if mydebug
          log('Available commands: ' +
            // add
            'ae [effect] - add effect, ' +
            'ai [item] - add item, ' +
            'ao [name] - add organ, ' +
            'as [skill] [amount] - add skill, ' +
            'at - add trait, ' +
            'cfg|config,<br/>' +
            'ch|chat - set chat stage' +
            'ddemo - debug: finish demo, ' +
            'dg - debug: graphics info, ' +
            'dthrow - debug: throw exception, ' +
            'dalert - debug: show alert, ' +
            'dleave - debug: leave area,<br/>' +
            // go
            'ga - go and enter area, ' +
            'gc - complete current goals, ' +
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
            'li [name] [level] - learn improvement, ' +
            'lr - learn region map, ' +
            'lt - learn all timeline,<br/>' +
            //
            'oa - organ action,<br/>' +
            'snd - play sound, r/restart, ' +
            's - set player stage, ' +
            'spa - spawn ai, ' +
            'spc - spawn civilian with job type, ' +
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

          // XXX spc <job type>
          else if (arr[0] == 'spc')
            spawnCivCommand(arr);

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
#end

      game.updateHUD(); // update HUD state
      if (game.location == LOCATION_AREA)
        {
          game.scene.updateCamera();
          game.area.updateVisibility();
        }
    }

// return command history size
  public function getHistoryLength(): Int
    {
      return history.length;
    }

// return history entry by index
  public function getHistoryEntry(index: Int): String
    {
      if (index < 0 || index >= history.length)
        return '';
      return history[index];
    }

// store command in history
  function recordHistory(cmd: String)
    {
      if (cmd == '')
        return;
      if (history.length > 0 && history[history.length - 1] == cmd)
        return;
      history.push(cmd);
      enforceHistoryLimit();
      saveHistory();
    }

// keep history within limit
  function enforceHistoryLimit()
    {
      while (history.length > 50)
        history.shift();
    }

// load history from disk
  function loadHistory()
    {
      history = [];
#if electron
      try {
        if (!Fs.existsSync('history.json'))
          return;
        var raw = Fs.readFileSync('history.json', 'utf8');
        if (raw != null && StringTools.trim(raw) != '')
          {
            var parsed: Dynamic = Json.parse(raw);
            var list: Array<Dynamic> = cast parsed;
            for (entry in list)
              if (Std.isOfType(entry, String))
                history.push(cast entry);
          }
      }
      catch (e: Dynamic)
        {
          trace('console history load failed: ' + e);
        }
#end
      enforceHistoryLimit();
    }

// save history to disk
  function saveHistory()
    {
#if electron
      try {
        Fs.writeFileSync(
          'history.json',
          Json.stringify(history, null, '  '),
          'utf8');
      }
      catch (e: Dynamic)
        {
          trace('console history save failed: ' + e);
        }
#end
    }

// complete current player goals
  function completeGoals()
    {
      for (g in @:privateAccess game.goals._listCurrent)
        game.goals.complete(g);
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
      addConsole.run('as psychology 80');
      addConsole.run('as coaxing 80');
      addConsole.run('as coercion 80');
      addConsole.run('as deception 80');
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

// spc <job type>
// spc
  function spawnCivCommand(arr: Array<String>)
    {
      if (arr.length < 2)
        {
          log('spc [job type] - spawn civilian with job type');
          log('spc - show job types');
          var jobTypes = game.jobs.getCivilianJobTypesList();
          log('Job types: ' + jobTypes.join(', '));
          return;
        }
      if (game.location != LOCATION_AREA)
        {
          log('Not in area.');
          return;
        }
      var jobType = arr[1];
      try {
        // override job info with specific type
        var isMale = (Std.random(100) < 50);
        var info = game.scene.images.getCivilianAI(jobType, isMale);
        if (info == null)
          {
            // try the other gender
            isMale = !isMale;
            info = game.scene.images.getCivilianAI(jobType, isMale);
            if (info == null)
              {
                log('Job type [' + jobType + '] not found.');
                return;
              }
          }
        var ai = game.area.spawnAI('civilian', game.playerArea.x, game.playerArea.y, false);
        ai.isMale = isMale;
        ai.tileAtlasX = info.x;
        ai.tileAtlasY = info.y;
        ai.job = info.job;
        ai.income = info.income;
        game.area.addAI(ai);
        
        // call job init function if present
        if (info.jobInfo != null && info.jobInfo.init != null)
          info.jobInfo.init(game, ai);
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

// handle learning improvements via console command
  function learnImprovementCommand(cmd: String)
    {
      var args = (cmd.length > 2 ? StringTools.trim(cmd.substr(2)) : '');
      var entries = addConsole.buildImprovementEntries();
      if (args == '')
        {
          log('Usage: li [name] [level]');
          log('Improvements: ' + addConsole.listEntryNames(entries));
          return;
        }
      var partsRaw = args.split(' ');
      var parts = [];
      for (part in partsRaw)
        if (part != '')
          parts.push(part);
      if (parts.length == 0)
        {
          log('Usage: li [name] [level]');
          return;
        }
      var level = -1;
      var tail = parts[parts.length - 1];
      var maybeLevel = Std.parseInt(tail);
      if (maybeLevel != null)
        {
          level = maybeLevel;
          parts.pop();
        }
      var query = parts.join(' ');
      if (query == '')
        {
          log('Usage: li [name] [level]');
          return;
        }
      var match = addConsole.selectMatch('improvement', query, entries);
      if (match == null)
        return;
      var info: ImprovInfo = null;
      try {
        info = EvolutionConst.getInfo(match.value);
      }
      catch (e: Dynamic)
        {
          info = null;
        }
      if (info == null)
        {
          log('Improvement info not found.');
          return;
        }
      var targetLevel = level;
      if (targetLevel < 0 || targetLevel > info.maxLevel)
        targetLevel = info.maxLevel;
      game.player.evolutionManager.addImprov(match.value, targetLevel);
      log('Learned ' + info.name + ' ' + targetLevel);
    }

// debug commands
  function debugCommand(cmd: String)
    {
      // XXX dg - show graphics objects info
      if (cmd.charAt(1) == 'g')
        {
          log('Disabled for now.');
        }
      // XXX dai - show ai view/hear info
      else if (cmd == 'dai')
        {
          log(
            'Window resolution: ' +
            game.scene.canvas.width + 'x' + game.scene.canvas.height +
            ', scale: ' + (game.config.mapScale * 100) +
            '%, tile resolution: ' +
            Std.int(game.scene.canvas.width / Const.TILE_SIZE) + 'x' +
            Std.int(game.scene.canvas.height / Const.TILE_SIZE) +
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
  public function goCommand(cmd: String)
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
          game.scene.updateCamera();
          game.scene.draw();
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
        learnImprovementCommand(cmd);

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


// set commands
  function setCommand(cmd: String)
    {
      if (stageConsole.run(cmd))
        {
          game.ui.closeWindow();
          return;
        }

      // XXX [sa] set area commands
      else if (cmd.charAt(1) == 'a')
        {
        }

      // fix for gui queue
      game.ui.closeWindow();
    }
// log function
  public inline function log(s: String)
    {
      game.log(Const.small(s), COLOR_DEBUG);
    }
}
