// game console helper

package console;

import const.*;
import game.*;
import haxe.Json;

class Console
{
  public var game: Game;
  var history: Array<String>;
  public var giveConsole: Give;
  public var goConsole: Go;
  var goalConsole: Goal;
  var learnConsole: Learn;
  var debugConsole: Debug;
  var stageConsole: Stage;
  var cultConsole: Cult;
  var modsConsole: Mods;
  public var completion: ConsoleCompletion;


  public function new(g: Game)
    {
      game = g;
      history = [];
      loadHistory();
      giveConsole = new Give(this);
      goConsole = new Go(this);
      goalConsole = new Goal(this);
      learnConsole = new Learn(this);
      debugConsole = new Debug(this);
      stageConsole = new Stage(this);
      cultConsole = new Cult(this);
      modsConsole = new Mods(this);
      completion = new ConsoleCompletion(this);
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

      // XXX ai trace|untrace <id>
      if (Const.isDebug && arr[0] == 'ai')
        aiTraceCommand(arr);

      // XXX config commands
      else if (char0 == 'c')
        {
          // XXX config|cfg <option> <value>
          if (arr[0] == 'config' || arr[0] == 'cfg')
            configOptionCommand(arr);
          else if (Const.isDebug)
            {
              // XXX chat|ch<stage>
              if (arr[0].length >= 2 && arr[0].substr(0, 2) == 'ch')
                chatCommand(arr);
              // XXX cult|cu commands
              else if (arr[0] == 'cu' || arr[0] == 'cult')
                cultConsole.run(cmd);
            }
        }

      // XXX debug <sub> commands
      else if (char0 == 'd')
        debugConsole.run(cmd);

      // XXX give, go, goal, god commands
      else if (Const.isDebug && char0 == 'g')
        {
          if (arr[0] == 'give')
            giveConsole.run(cmd);
          else if (arr[0] == 'go')
            goConsole.run(cmd);
          else if (arr[0] == 'goal')
            goalConsole.run(cmd);
          else if (arr[0] == 'god')
            setVariableCommand(['set', 'player.godmode', '1' ]);
        }

      // XXX help
      else if (char0 == 'h')
        {
          if (Const.isDebug)
            log('Available commands: ' +
              // give
              'give effect [name], ' +
              'give item [name], ' +
              'give organ [name], ' +
              'give skill [name] [amount], ' +
              'give trait [name], ' +
              'give evolution [name] [level],<br/>' +
              'ai trace|untrace [id] - toggle AI browser-console trace,<br/>' +
              'cfg|config, ' +
              'ch|chat - set chat stage,<br/>' +
              // debug
              'debug renderstats, ' +
              'debug ai, ' +
              'debug sound, ' +
              'debug lights, ' +
              'debug colors, ' +
              'debug alert, ' +
              'debug demo, ' +
              'debug leave, ' +
              'debug throw,<br/>' +
              // go
              'go area [x] [y], ' +
              'go event [index], ' +
              'go xy [x] [y], ' +
              'goal complete [id], ' +
              'goal receive [id], ' +
              'god - enable godmode,<br/>' +
              // info
              'ie - timeline info (trace), ' +
              'ii - improvements info (trace),<br/>' +
              // learn
              'learn clues, ' +
              'learn event [index], ' +
              'learn improvements [level], ' +
              'learn region, ' +
              'learn timeline, ' +
              'load - load game,<br/>' +
              //
              'oa - organ action,<br/>' +
              'mods [list|enable <id>|disable <id>|errors|rescan],<br/>' +
              'snd - play sound, r/restart, ' +
              's - set player stage, ' +
              'spa - spawn ai, ' +
              'spc - spawn civilian with job type, ' +
              'save - save game, ' +
              'set - set game variable, ' +
              'quit.');
          else
            log('Available commands: cfg, config, ' +
              'debug renderstats, ' +
              'debug ai, ' +
              'debug sound, ' +
              'debug lights, ' +
              'debug colors, ' +
              'load - load game, ' +
              'mods [list|enable <id>|disable <id>|errors|rescan], ' +
              'restart, ' +
              'save - save game, ' +
              'quit.');
        }

      // XXX mods commands (release + debug)
      else if (char0 == 'm')
        modsConsole.run(arr);

      // XXX info commands
      else if (Const.isDebug && char0 == 'i')
        infoCommand(cmd);

      // XXX load + learn commands
      else if (char0 == 'l')
        {
          // XXX load game
          if (arr[0] == 'load' || arr[0] == 'lo')
            game.load(1);

          else if (Const.isDebug)
            learnConsole.run(cmd);
        }

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

          else if (Const.isDebug)
            {
              // XXX set <variable> <value>
              if (arr[0] == 'set')
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
            }
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
      else if ((char0 == 'q' && cmd.length == 1) ||
              cmd == 'quit')
// exit game
#if electron
        HostBridge.quit();
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
        if (!HostBridge.consoleHistoryExists())
          return;
        var raw = HostBridge.consoleHistoryRead();
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
        HostBridge.consoleHistoryWrite(Json.stringify(history, null, '  '));
      }
      catch (e: Dynamic)
        {
          trace('console history save failed: ' + e);
        }
#end
    }


// ai trace|untrace <id> - toggle browser-console turn trace for one AI
  function aiTraceCommand(arr: Array<String>)
    {
      if (arr.length < 3 ||
          (arr[1] != 'trace' &&
           arr[1] != 'untrace'))
        {
          log('ai trace [id] - enable AI browser-console trace');
          log('ai untrace [id] - disable AI browser-console trace');
          return;
        }
      if (game.location != LOCATION_AREA ||
          game.area == null)
        {
          log('Not in area.');
          return;
        }
      var id = Std.parseInt(arr[2]);
      if (id == null)
        {
          log('AI ID [' + arr[2] + '] is invalid.');
          return;
        }
      var ai = game.area.getAIByID(id);
      if (ai == null)
        {
          log('AI [' + id + '] not found.');
          return;
        }
      ai.isTracing = (arr[1] == 'trace');
      log('AI [' + id + '] trace ' + (ai.isTracing ? 'enabled' : 'disabled') +
        '.');
    }


// chat<stage>
// chat
  function chatCommand(arr: Array<String>)
    {
      var cmd = arr[0];
      if (cmd == 'chat' || cmd == 'ch')
        {
          log(';ch1 - affinity + skills<br/>' +
            ';ch2 - stage 1 + host high consent<br/>' +
            ';ch3 - stage 1 + host max consent<br/>' +
            ';ch4 - active target full consent<br/>'
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
            game.player.host.affinity = 100;
            game.player.host.chat.consent = 100;
          case 4:
            if (!game.player.chat.debugGiveFullConsent())
              log('Need active chat target.');
        }
    }

// stage 1: skills + affinity
  function chatStage1()
    {
      game.player.host.affinity = 80;
      giveConsole.run('give skill psychology 80');
      giveConsole.run('give skill coaxing 80');
      giveConsole.run('give skill coercion 80');
      giveConsole.run('give skill deception 80');
    }

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
