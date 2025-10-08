// game console

package game;

import ai.*;
import const.*;
import haxe.Json;
import objects.EventObject;
#if electron
import js.node.Fs;
#end

class ConsoleGame
{
  public var game: Game;
  var history: Array<String>;


  public function new(g: Game)
    {
      game = g;
      history = [];
      loadHistory();
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
        addCommand(cmd, arr);

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
            'dleave - debug: leave area, ' +
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
        addEffectCommand(cmd, arr);

      // XXX [ai pistol] add item X
      else if (cmd.charAt(1) == 'i')
        addItemCommand(cmd, arr);

      // XXX [ao10] add organ X
      else if (cmd.charAt(1) == 'o')
        addOrganCommand(cmd, arr);

      // XXX [as computer 10] add skill X Y
      else if (cmd.charAt(1) == 's')
        addSkillCommand(cmd, arr);

      // XXX [at] add trait by id
      else if (cmd.charAt(1) == 't')
        addTraitCommand(arr);

    }

// handle adding effects via console command
  function addEffectCommand(cmd: String, _arr: Array<String>)
    {
      var args = (cmd.length > 2 ? StringTools.trim(cmd.substr(2)) : '');
      var entries = buildEffectEntries();
      if (args == '')
        {
          log('Effects: ' + listEntryNames(entries));
          return;
        }
      var match = selectMatch('effect', args, entries);
      if (match == null)
        return;
      if (game.player.state != PLR_STATE_HOST)
        {
          log('Not on host.');
          return;
        }
      var effect: Effect = null;
      switch (match.value)
        {
          case _AIEffectType.EFFECT_PARALYSIS:
            effect = new effects.Paralysis(game, 10);
          case _AIEffectType.EFFECT_SLIME:
            effect = new effects.Slime(game, 10);
          case _AIEffectType.EFFECT_PANIC:
            effect = new effects.Panic(game, 10);
          case _AIEffectType.EFFECT_CANNOT_TEAR_AWAY:
            effect = new effects.CannotTearAway(game, 10);
          case _AIEffectType.EFFECT_CRYING:
            effect = new effects.Crying(game, 10);
          case _AIEffectType.EFFECT_BERSERK:
            effect = new effects.Berserk(game, 10);
          case _AIEffectType.EFFECT_WHITE_POWDER:
            effect = new effects.WhitePowder(game, 10);
          case _AIEffectType.EFFECT_WITHDRAWAL:
            effect = new effects.Withdrawal(game, 10);
          case _AIEffectType.EFFECT_DRUNK:
            effect = new effects.Drunk(game, 10);
        }
      if (effect == null)
        {
          log('Effect handler not implemented: ' + match.name + '.');
          return;
        }
      game.player.host.onEffect(effect);
      log('Added effect: ' + match.name + '.');
    }

// handle adding items via console command
  function addItemCommand(cmd: String, _arr: Array<String>)
    {
      var args = (cmd.length > 2 ? StringTools.trim(cmd.substr(2)) : '');
      if (ItemsConst.infos == null)
        ItemsConst.init(game);
      var entries = buildItemEntries();
      if (args == '')
        {
          log('Items: ' + listEntryNames(entries));
          return;
        }
      var match = selectMatch('item', args, entries);
      if (match == null)
        return;
      if (game.player.state != PLR_STATE_HOST)
        {
          log('Not on host.');
          return;
        }
      try {
        var item = game.player.host.inventory.addID(match.value);
        if (item.name == 'keycard')
          item.lockID = 'corp-mission';
      }
      catch (e: Dynamic)
        {
          game.log(e + '');
          return;
        }
      game.log('Item added.');
    }

// handle adding organs via console command
  function addOrganCommand(cmd: String, _arr: Array<String>)
    {
      var args = (cmd.length > 2 ? StringTools.trim(cmd.substr(2)) : '');
      var entries = buildOrganEntries();
      if (args == '')
        {
          log('Organs: ' + listEntryNames(entries));
          return;
        }
      var match = selectMatch('organ', args, entries);
      if (match == null)
        return;
      if (game.player.state != PLR_STATE_HOST)
        {
          log('Not on host.');
          return;
        }
      var info: EvolutionConst.ImprovInfo = null;
      try {
        info = EvolutionConst.getInfo(match.value);
      }
      catch (e: Dynamic)
        {
          info = null;
        }
      if (info == null)
        {
          log('Improvement [' + match.name + '] not found.');
          return;
        }
      if (info.organ == null)
        {
          log('Improvement [' + match.name + '] has no organ.');
          return;
        }
      game.player.evolutionManager.addImprov(match.value, info.maxLevel);
      game.player.host.organs.action('set.' + Std.string(match.value));
      game.player.host.organs.debugCompleteCurrent();
      game.log('Organ added: ' + info.organ.name + '.');
    }

// handle adding skills via console command
  function addSkillCommand(cmd: String, _arr: Array<String>)
    {
      var args = (cmd.length > 2 ? StringTools.trim(cmd.substr(2)) : '');
      var entries = buildSkillEntries();
      if (args == '')
        {
          log('Usage: as [skill] [amount]');
          log('Skills: ' + listEntryNames(entries));
          return;
        }
      var partsRaw = args.split(' ');
      var parts = [];
      for (part in partsRaw)
        if (part != '')
          parts.push(part);
      if (parts.length < 2)
        {
          log('Usage: as [skill] [amount]');
          return;
        }
      var amountStr = parts[parts.length - 1];
      var queryParts = [];
      for (i in 0...parts.length - 1)
        queryParts.push(parts[i]);
      var query = queryParts.join(' ');
      if (query == '')
        {
          log('Usage: as [skill] [amount]');
          return;
        }
      var parsed = Std.parseInt(amountStr);
      if (parsed == null)
        {
          log('Invalid amount: ' + amountStr + '.');
          return;
        }
      var match = selectMatch('skill', query, entries);
      if (match == null)
        return;
      var amount: Int = parsed;
      game.player.skills.addID(match.value, amount);
      game.log('Skill/knowledge added: ' + match.name + ' (' + amount + ').');
    }

// handle learning improvements via console command
  function learnImprovementCommand(cmd: String)
    {
      var args = (cmd.length > 2 ? StringTools.trim(cmd.substr(2)) : '');
      var entries = buildImprovementEntries();
      if (args == '')
        {
          log('Usage: li [name] [level]');
          log('Improvements: ' + listEntryNames(entries));
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
      var match = selectMatch('improvement', query, entries);
      if (match == null)
        return;
      var info: EvolutionConst.ImprovInfo = null;
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

// add trait command handler
  function addTraitCommand(arr: Array<String>)
    {
      if (game.player.state != PLR_STATE_HOST)
        {
          log('Not on host.');
          return;
        }

      var entries = [];
      for (trait in Type.allEnums(_AITraitType))
        {
          var enumName = Std.string(trait);
          var key = enumName.substr(6).toLowerCase();
          entries.push({
            id: trait,
            key: key,
            enumName: enumName
          });
        }
      entries.sort(function(a, b)
        {
          if (a.key < b.key) return -1;
          if (a.key > b.key) return 1;
          return 0;
        });

      if (arr.length < 2 || arr[1] == '')
        {
          var names = [];
          for (entry in entries)
            names.push(entry.key);
          log('Traits: ' + names.join(', '));
          return;
        }

      var query = arr[1].toLowerCase();
      var match = null;
      for (entry in entries)
        if (entry.key == query)
          {
            match = entry;
            break;
          }

      if (match == null)
        {
          var matches = [];
          for (entry in entries)
            if (StringTools.startsWith(entry.key, query))
              matches.push(entry);
          if (matches.length == 1)
            match = matches[0];
          else if (matches.length > 1)
            {
              var options = new Array<String>();
              for (entry in matches)
                options.push(entry.key);
              log('Ambiguous trait id, matches: ' + options.join(', '));
              return;
            }
        }

      if (match == null)
        {
          log('No trait matches id: ' + query);
          return;
        }

      game.player.host.addTrait(match.id);
      log('Added trait: ' + match.enumName);
    }

// build effect entries for selection
  function buildEffectEntries(): Array<{ name: String, searchKey: String, value: _AIEffectType, ?aliases: Array<String> }>
    {
      var list = [];
      for (effect in Type.allEnums(_AIEffectType))
        {
          var name = Std.string(effect).substr(7).toLowerCase();
          list.push({
            name: name,
            searchKey: normalizeKey(name),
            value: effect
          });
        }
      list.sort(function(a, b)
        {
          return compareStrings(a.name, b.name);
        });
      return list;
    }

// build item entries for selection
  function buildItemEntries(): Array<{ name: String, searchKey: String, value: String, ?aliases: Array<String> }>
    {
      var list = [];
      for (info in ItemsConst.infos)
        {
          var name = info.id;
          list.push({
            name: name,
            searchKey: normalizeKey(name),
            value: info.id
          });
        }
      list.sort(function(a, b)
        {
          return compareStrings(a.name, b.name);
        });
      return list;
    }

// build organ entries for selection
  function buildOrganEntries(): Array<{ name: String, searchKey: String, value: _Improv, ?aliases: Array<String> }>
    {
      var list = [];
      for (improv in Type.allEnums(_Improv))
        {
          var name = Std.string(improv).substr(4).toLowerCase();
          var info: EvolutionConst.ImprovInfo = null;
          try {
            info = EvolutionConst.getInfo(improv);
          }
          catch (e: Dynamic)
            {
              info = null;
            }
          if (info == null || info.organ == null)
            continue;
          list.push({
            name: name,
            searchKey: normalizeKey(name),
            value: improv
          });
        }
      list.sort(function(a, b)
        {
          return compareStrings(a.name, b.name);
        });
      return list;
    }

// build skill entries for selection
  function buildSkillEntries(): Array<{ name: String, searchKey: String, value: _Skill, ?aliases: Array<String> }>
    {
      var list = [];
      for (info in SkillsConst.skills)
        {
          var name = info.name.toLowerCase();
          list.push({
            name: name,
            searchKey: normalizeKey(name),
            value: info.id
          });
        }
      list.sort(function(a, b)
        {
          return compareStrings(a.name, b.name);
        });
      return list;
    }

// build improvement entries for selection
  function buildImprovementEntries(): Array<{ name: String, searchKey: String, value: _Improv, ?aliases: Array<String> }>
    {
      var list = [];
      for (improv in Type.allEnums(_Improv))
        {
          var info: EvolutionConst.ImprovInfo = null;
          try {
            info = EvolutionConst.getInfo(improv);
          }
          catch (e: Dynamic)
            {
              info = null;
            }
          if (info == null)
            continue;
          var name = Std.string(improv).substr(4).toLowerCase();
          list.push({
            name: name,
            searchKey: normalizeKey(name),
            value: improv
          });
        }
      list.sort(function(a, b)
        {
          return compareStrings(a.name, b.name);
        });
      return list;
    }

// format entry names for logging
  function listEntryNames<T>(entries: Array<{ name: String, searchKey: String, value: T, ?aliases: Array<String> }>): String
    {
      var names = [];
      for (entry in entries)
        names.push(entry.name);
      names.sort(compareStrings);
      return names.join(', ');
    }

// select matching entry for a query
  function selectMatch<T>(label: String, query: String, entries: Array<{ name: String, searchKey: String, value: T, ?aliases: Array<String> }>)
    {
      var normalizedQuery = normalizeKey(query);
      var exact = [];
      var partial = [];
      for (entry in entries)
        {
          var keys = [ entry.searchKey ];
          if (entry.aliases != null)
            for (alias in entry.aliases)
              keys.push(alias);
          var isExact = false;
          for (key in keys)
            if (key == normalizedQuery)
              {
                exact.push(entry);
                isExact = true;
                break;
              }
          if (isExact)
            continue;
          if (normalizedQuery == '')
            continue;
          for (key in keys)
            if (key.indexOf(normalizedQuery) != -1)
              {
                partial.push(entry);
                break;
              }
        }
      var matches = exact.length > 0 ? exact : partial;
      if (matches.length == 0)
        {
          log('No ' + label + ' matched "' + query + '".');
          return null;
        }
      if (matches.length > 1)
        {
          var options = [];
          for (entry in matches)
            options.push(entry.name);
          options.sort(compareStrings);
          log('Ambiguous ' + label + ' match: ' + options.join(', '));
          return null;
        }
      return matches[0];
    }

// convert value to a normalized lookup key
  inline function normalizeKey(value: String): String
    {
      var s = StringTools.trim(value).toLowerCase();
      s = StringTools.replace(s, '_', '');
      s = StringTools.replace(s, '-', '');
      s = StringTools.replace(s, ' ', '');
      return s;
    }

// compare strings ignoring case
  inline function compareStrings(a: String, b: String): Int
    {
      var la = a.toLowerCase();
      var lb = b.toLowerCase();
      if (la < lb) return -1;
      if (la > lb) return 1;
      return 0;
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
            ';s3 - set player stage 3 (stage 2.3 + spaceship)<br/>' +
            ';s31 - set player stage 3.1 (stage 3 + ready to launch)'
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

          // stage 3.1: 3 + launch ready
          else if (stage == 31)
            {
              stage1();
              stage2();
              stage21();
              stage22();
              stage23();
              stage3();
              stage31();
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

// stage 3.1: stage 3 + ready to launch
  function stage31()
    {
      game.player.vars.npcEnabled = true;
      game.player.vars.searchEnabled = true;
      var state = @:privateAccess scenario.GoalsAlienCrashLanding.getSpaceshipState(game);
      state.part1Installed = true;
      state.part2Installed = true;
      state.part3Installed = true;
    }

// log function
  inline function log(s: String)
    {
      game.log(Const.small(s), COLOR_DEBUG);
    }
}
