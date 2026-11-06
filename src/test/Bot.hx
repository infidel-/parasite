// player emulator for the tests: what the player could do right now, and doing one of it
//
// every option goes through the entry point the keyboard or a click uses (ActionsHud.action and
// keyAction, UI.handleMovement, UI.onKey for Escape, a window's own action(index), UI.closeWindow),
// never through a shortcut into the logic behind it, so a bot's game exercises the paths a player's
// does. The only rules copied from the UI are the three window gates in options(). Numbered actions
// are NOT pressed as keys: a key press clicks the button on a deferred timer (UI.pressButton), and
// ActionsHud.action is what that click lands on.
//
// shared by the headless runner (test.Headless) and the in-game `bot` console command. Its choices
// come from its own seeded stream, so it never draws from the game's Math.random.

package test;

import game.Game;

typedef _BotOption = {
  var kind: String; // move, act, window, escape, answer: what the random policy weighs
  var label: String; // what it does, for the trail
  var f: Void -> Void; // do it
  @:optional var id: String; // the action id behind it, for the goal policy to look for
}

class Bot
{
  // how often the random policy picks each kind, when the kind is on offer at all
  static var WEIGHTS = [
    'move' => 45,
    'act' => 35,
    'window' => 8,
    'escape' => 12,
    'answer' => 100,
  ];
  static inline var TRAIL = 30;
  // the area alertness the goal policy leaves an area at, before the police it calls in arrive
  static inline var FLEE = 50;
  // the parasite energy it stops hardening a grip at and invades early
  static inline var LOW_ENERGY = 15;
  // the host energy a trip on the region map needs; below it the host is changed first
  static inline var TRIP_ENERGY = 50;

  var game: Game;
  var rng: Void -> Float;
  public var trail: Array<String>; // the last TRAIL steps taken, newest last
  public var policy: String; // random, or goal: work through the tutorial, timeline and habitat goals (random where it has no say)
  var walkFailed = false; // the goal policy's last walk had no path: hand the next step to random
  var fled: game.AreaGame = null; // the area the goal policy last fled, not to be entered again straight away
  var opened = ''; // the window the goal policy last opened, and the turn it did (one try a turn each)
  var openedTurn = -1;

  public function new(g: Game, seed: Int, policy: String)
    {
      game = g;
      rng = gen.Rng.mulberry32(seed);
      trail = [];
      this.policy = policy;
    }

// seed Math.random for a game about to start, and clear what the last game left behind, so a seed
// is the same game whatever ran before it: the headless runs and `bot seed` both start here.
// Std.random compiles to Math.random, so one stream covers every roll
  public static function seed(g: Game, seed: Int)
    {
      js.Syntax.code("Math.random = {0}", gen.Rng.mulberry32(seed));
      // Game.restartPre resets only the region and cult id counters; the rest carry on from the
      // previous game, which a second New Game in one session shrugs off but which would make a
      // seed's game depend on the games played before it
      game.AreaGame._maxID = 0;
      ai.AIData._maxID = 0;
      objects.AreaObject._maxID = 0;
      cult.Mission._maxID = 0;
      cult.base.CultBaseOrgan._maxID = 0;
      cult.base.RivalBaseOrgan._maxID = 0;
      region.RegionObject._maxID = 1;
      @:privateAccess scenario.NPC._maxID = 0;
      // Game.init logs its first lines BEFORE it zeroes turns, so they carry the last game's turn
      // (TODO.md)
      g.turns = 0;
      // the stage presets switch these off and only the Game constructor switches them back on
      g.importantMessagesEnabled = true;
      // the profile outlives a game by design (unlocked pedia articles and the like); headless, a new
      // one is a fresh install, in the game it rereads the player's own
      g.profile = new Profile(g);
    }

// pick one option and do it; false when there is nothing left to do
  public function step(): Bool
    {
      var list = options();
      if (list.length == 0)
        return false;
      var o = (policy == 'goal' ? goal(list) : null);
      if (o == null)
        o = pick(list);
      trail.push('T' + game.turns + ' ' + o.label);
      if (trail.length > TRAIL)
        trail.shift();
      o.f();
      return true;
    }

// everything the player could do right now; empty once the game is over
  public function options(): Array<_BotOption>
    {
      var list: Array<_BotOption> = [];
      if (game.state == GAMESTATE_FINISH)
        return list;
      var ui = game.ui;
      if (ui.state != UISTATE_DEFAULT)
        {
          windowOptions(list);
          return list;
        }
      // a rebirth waits on the window queue draining (UI.closeWindow -> Game.endRebirth)
      if (game.state == GAMESTATE_REBIRTH)
        {
          list.push({
            kind: 'answer',
            label: 'close (rebirth)',
            f: ui.closeWindow,
          });
          return list;
        }

      // the action list and the keyboard-only actions, as the HUD shows them
      var i = 1;
      for (a in @:privateAccess ui.hud.actions.listActions)
        {
          var index = i++;
          list.push({
            kind: 'act',
            label: 'act ' + index + ' ' + a.id,
            f: function() ui.hud.action(index, false),
            id: a.id,
          });
        }
      for (a in @:privateAccess ui.hud.actions.listKeyActions)
        {
          // these enter targeting, which only the mouse or a target key leaves usefully
          if (a.id == 'targetMode' ||
              a.id == 'shootTarget' ||
              a.id == 'attackTarget')
            continue;
          var key = a.key;
          list.push({
            kind: 'act',
            label: 'key ' + key + ' ' + a.id,
            f: function() ui.hud.keyAction(key),
            id: a.id,
          });
        }

      // the eight directions, through the keyboard handler
      for (code in [ 'Numpad1', 'Numpad2', 'Numpad3', 'Numpad4', 'Numpad6', 'Numpad7', 'Numpad8', 'Numpad9' ])
        list.push({
          kind: 'move',
          label: 'move ' + code,
          f: function() @:privateAccess ui.handleMovement('', code),
        });

      // a hud sub-mode (chat, command menu, pickup, targeting, base building) is left with Escape
      if (ui.hud.state != HUD_DEFAULT)
        list.push(escape());

      // the windows the navbar would show (the same gates as UI.onKey and NavbarHud)
      else
        {
          var p = game.player;
          if (p.state == PLR_STATE_HOST &&
              p.evolutionManager.state > 0)
            list.push(open(UISTATE_EVOLUTION));
          if (game.cults[0].state == CULT_STATE_ACTIVE)
            list.push(open(UISTATE_CULT));
          if (p.vars.inventoryEnabled ||
              p.vars.skillsEnabled ||
              p.vars.organsEnabled)
            list.push(open(UISTATE_BODY));
        }
      return list;
    }

// what an open window offers: its own actions, an answer to a question, or a way out
  function windowOptions(list: Array<_BotOption>)
    {
      var ui = game.ui;
      var w = @:privateAccess ui.components[ui.state];
      switch (ui.state)
        {
          case UISTATE_FINISH:
            return;
          case UISTATE_YESNO:
            for (i in 1...3)
              list.push({
                kind: 'answer',
                label: (i == 1 ? 'yes' : 'no'),
                f: function() w.action(i),
              });
          case UISTATE_CHOICE:
            var c: ui.Choice = cast w;
            var n = @:privateAccess c.params.buttons.length;
            for (i in 1...n + 1)
              list.push({
                kind: 'answer',
                label: 'choice ' + i,
                f: function() w.action(i),
              });
          case UISTATE_EVOLUTION, UISTATE_CULT:
            w.update();
            var actions: Array<_PlayerAction> = (ui.state == UISTATE_EVOLUTION ?
              @:privateAccess (cast w: ui.Evolution).listActions :
              @:privateAccess (cast w: ui.Cult).listActions);
            for (i in 0...actions.length)
              {
                var index = i + 1;
                list.push({
                  kind: 'act',
                  label: 'window ' + index + ' ' + actions[i].id,
                  f: function() w.action(index),
                  id: actions[i].id,
                });
              }
            list.push(escape());
          case UISTATE_BODY:
            var b: ui.Body = cast w;
            b.update();
            // Body takes a prefix key first (inventory or organs), then the number
            for (prefix in [ 'inventory', 'body' ])
              {
                var actions = (prefix == 'inventory' ?
                  @:privateAccess b.listInventoryActions :
                  @:privateAccess b.listOrgansActions);
                for (i in 0...actions.length)
                  {
                    var index = i + 1;
                    list.push({
                      kind: 'act',
                      label: prefix + ' ' + index + ' ' + actions[i].id,
                      f: function() {
                        @:privateAccess b.actionPrefix = prefix;
                        b.action(index);
                      },
                      id: actions[i].id,
                    });
                  }
              }
            list.push(escape());
          default:
            // a message, or a window the game opened on its own: the player closes it
            list.push({
              kind: 'answer',
              label: 'close ' + ui.state,
              f: ui.closeWindow,
            });
        }
    }

// open a window as its navbar cell would
  function open(state: _UIState): _BotOption
    {
      return {
        kind: 'window',
        label: 'open ' + state,
        f: function() game.ui.state = state,
        id: 'open.' + state,
      };
    }

// the option opening this window, unless the goal policy opened it already this turn: a window
// with nothing to do in it is escaped, and opening it again straight away would loop
  function openOnce(list: Array<_BotOption>, state: _UIState): _BotOption
    {
      if (opened == state &&
          openedTurn == game.turns)
        return null;
      opened = state;
      openedTurn = game.turns;
      return find(list, 'open.' + state);
    }

// press Escape through the real keyboard handler
  function escape(): _BotOption
    {
      return {
        kind: 'escape',
        label: 'escape',
        id: 'escape',
        f: function() @:privateAccess game.ui.onKey(cast {
          key: 'Escape',
          code: 'Escape',
          keyCode: 27,
          altKey: false,
          ctrlKey: false,
          shiftKey: false,
          preventDefault: function() {},
        }),
      };
    }

// the goal policy: what a player working through the tutorial chain (const.Goals) would do next,
// or null to leave the step to the random policy. It reads the game to choose, and acts only
// through the options the player has
  function goal(list: Array<_BotOption>): _BotOption
    {
      var ui = game.ui;
      var p = game.player;
      var pa = game.playerArea;
      // a question or a message: say yes, close it
      for (o in list)
        if (o.kind == 'answer')
          return o;
      var evo = p.evolutionManager;
      var imp = wantedImprov();
      if (ui.state == UISTATE_EVOLUTION)
        {
          var o = (imp != null ? find(list, 'set.' + imp) : null);
          return (o != null &&
            !(evo.isActive &&
              evo.taskID == imp) ? o : find(list, 'escape'));
        }
      // the body window is where an item is learned, and a paper read for its clues (a book wants a
      // habitat)
      if (ui.state == UISTATE_BODY)
        {
          for (o in list)
            if (o.id != null &&
                (StringTools.startsWith(o.id, 'learn.') ||
                 (o.id == 'read.paper' &&
                  wantsClues()) ||
                 // an organ (the feature list's ids are set.<improvement>)
                 (StringTools.startsWith(o.id, 'set.') &&
                  game.goals.has(GOAL_GROW_ORGAN)) ||
                 (StringTools.startsWith(o.id, 'search.') &&
                  game.goals.has(GOAL_USE_COMPUTER) &&
                  game.area.isHabitat)))
              return o;
          return find(list, 'escape');
        }
      if (ui.state != UISTATE_DEFAULT)
        return null;
      if (game.location == LOCATION_REGION)
        return region(list);
      if (game.location != LOCATION_AREA)
        return null;
      // the target was out of reach (behind a wall, a locked door): a random step moves things on
      if (walkFailed)
        {
          walkFailed = false;
          return null;
        }
      // a walk under way goes on, one waypoint a step, as Game.update steps a clicked path
      if (pa.path != null)
        return {
          kind: 'move',
          label: 'follow path',
          f: game.update,
        };

      // the computer goal wants a host carrying a device, and one who knows computers while the
      // parasite does not
      var human = (game.goals.has(GOAL_USE_COMPUTER) ?
        nearestAI(true, computerHost) : nearestAI(true));
      if (human == null)
        human = nearestAI(true);
      if (p.state == PLR_STATE_PARASITE)
        {
          // a dog only when there is no human about: every goal past the first needs a human
          var here = game.area.getAI(pa.x, pa.y);
          var o = find(list, 'attachHost');
          if (o != null &&
              (human == null ||
               (here != null &&
                here.isHuman)))
            return o;
          var ai = (human != null ? human : nearestAI(false));
          return (ai != null ? walk(ai.x, ai.y) : null);
        }
      // a host that fights the grip outlasts a starving parasite: risk the early invasion then, once
      // the grip gives it a fair chance (each failure costs the parasite 2 health)
      if (p.state == PLR_STATE_ATTACHED)
        return first(list, (p.energy <= LOW_ENERGY &&
          pa.attachHold >= 50 &&
          p.health > 2 ?
          [ 'invadeHost', 'invadeEarly', 'hardenGrip' ] :
          [ 'invadeHost', 'hardenGrip', 'invadeEarly' ]));

      // in a host
      var host = p.host;
      if (p.hostControl < 50)
        {
          var o = find(list, 'reinforceControl');
          if (o != null)
            return o;
        }
      // the next improvement set evolving; the probe is waited for, since the next goals need it, and
      // the rest evolves while the bot goes on
      if (imp != null &&
          !(evo.isActive &&
            evo.taskID == imp))
        {
          var o = openOnce(list, _UIState.UISTATE_EVOLUTION);
          if (o != null)
            return o;
        }
      if (imp == IMP_BRAIN_PROBE &&
          evo.isActive)
        return find(list, 'skipTurn');
      // whatever the host carries, learned (in the body window) before its brain is wrung
      // (a dog's inventory is unavailable there, as ui.Body.updateInventory has it)
      if (p.vars.inventoryEnabled &&
          host.isHuman)
        for (item in host.inventory.withWorn())
          if (!p.knowsItem(item.id))
            {
              var o = openOnce(list, _UIState.UISTATE_BODY);
              if (o != null)
                return o;
            }
      // an organ grown in the body window, for GROW_ORGAN
      if (game.goals.has(GOAL_GROW_ORGAN) &&
          @:privateAccess host.organs.currentOrgan == null)
        {
          var o = openOnce(list, _UIState.UISTATE_BODY);
          if (o != null)
            return o;
        }
      // in the habitat, a ready host searches its device for the computer goal; any other host
      // has no business there
      var ready = computerReady();
      if (game.area.isHabitat &&
          game.goals.has(GOAL_USE_COMPUTER))
        {
          if (ready)
            {
              var o = openOnce(list, _UIState.UISTATE_BODY);
              return (o != null ? o : find(list, 'skipTurn'));
            }
          var o = leave(list);
          if (o != null)
            return o;
        }
      // a hot area is left before the police it calls in arrive; the sewers goal leaves the same way,
      // and so does a timeline goal that wants another area
      var target = eventArea();
      if (host.isHuman &&
          !game.area.isHabitat &&
          (game.area.alertness >= FLEE ||
           ((game.goals.has(GOAL_ENTER_SEWERS) ||
             game.goals.has(GOAL_CREATE_HABITAT) ||
             ready ||
             (target != null &&
              target != game.area)) &&
            host.energy >= TRIP_ENERGY)))
        {
          if (game.area.alertness >= FLEE)
            fled = game.area;
          var o = leave(list);
          if (o != null)
            return o;
        }
      // the event area: papers picked up and read, an event participant's brain probed
      if (target == game.area &&
          host.isHuman &&
          !host.hasTrait(TRAIT_ILLITERATE))
        {
          if (host.inventory.has('paper') &&
              host.energy > 10)
            {
              var o = openOnce(list, _UIState.UISTATE_BODY);
              if (o != null)
                return o;
            }
          // an unknown paper is learned about before it can be picked up
          var o = first(list, [ 'get', 'pickupMenu', 'learnObject' ]);
          if (o != null)
            return o;
          if (host.inventory.length() < host.maxItems)
            for (doc in game.area.getObjects())
              if (doc.type == 'document' &&
                  doc.item.id == 'paper')
                return walk(doc.x, doc.y);
        }
      // a probe takes health off the host: stop while it can still carry the parasite to the next one.
      // past the tutorial only an event participant has anything left to tell
      var o = find(list, 'probeBrain');
      if (o != null &&
          host.isHuman &&
          host.health > 3 &&
          (!game.goals.completed(GOAL_LEARN_SOCIETY) ||
           (host.isNPC &&
            !host.npc.memoryKnown &&
            wantsClues()) ||
           (game.goals.has(GOAL_USE_COMPUTER) &&
            p.skills.getLevel(SKILL_COMPUTER) == 0 &&
            host.skills.getLevel(SKILL_COMPUTER) > 0)))
        return o;
      // a spent host, or a dog, is a ride to the nearest human: walk it there, step out next to them
      if (!host.isHuman ||
          host.health <= 3 ||
          host.energy < 20 ||
          !game.goals.completed(GOAL_LEARN_SOCIETY) ||
          (target == game.area &&
           host.hasTrait(TRAIT_ILLITERATE)) ||
          (target != null &&
           target != game.area &&
           host.energy < TRIP_ENERGY) ||
          (game.goals.has(GOAL_USE_COMPUTER) &&
           !computerHost(host) &&
           human != null &&
           computerHost(human)))
        {
          if (human == null)
            return null;
          if (Math.max(Math.abs(human.x - pa.x), Math.abs(human.y - pa.y)) <= 1)
            return find(list, 'leaveHost');
          return walk(human.x, human.y);
        }
      return find(list, 'skipTurn');
    }

// on the region map: to the event area while a timeline goal wants it, else into the nearest calm
// inhabited area that is not the one just fled
  function region(list: Array<_BotOption>): _BotOption
    {
      var pr = game.playerRegion;
      if (pr.target != null)
        return {
          kind: 'move',
          label: 'follow region path',
          f: game.update,
        };
      // a habitat is made in the sewers under the first inhabited area it gets to
      var o = find(list, 'createHabitat');
      if (o != null &&
          game.goals.has(GOAL_CREATE_HABITAT))
        return o;
      // a host ready for the computer goal goes to the habitat
      if (game.goals.has(GOAL_USE_COMPUTER) &&
          computerReady())
        {
          var o = find(list, 'enterHabitat');
          if (o != null)
            return o;
          for (a in game.region)
            if (a.hasHabitat)
              {
                var x = a.x;
                var y = a.y;
                return {
                  kind: 'move',
                  label: 'travel ' + x + ',' + y + ' (habitat)',
                  f: function() pr.setTarget(x, y),
                };
              }
        }
      // a parasite, or a host about to expire, needs a new host before anywhere else
      var p = game.player;
      var target = (p.state == PLR_STATE_HOST &&
        p.host.energy >= 20 ? eventArea() : null);
      // a hot event area is waited out next to it: alertness falls by one a turn out here
      if (target != null &&
          target == pr.currentArea &&
          target.alertness >= FLEE)
        return find(list, 'skipTurn');
      if (target == null)
        {
          var bestD = 0;
          for (a in game.region)
            {
              if (!canEnter(a) ||
                  !a.info.isInhabited ||
                  a == fled ||
                  a.alertness >= FLEE)
                continue;
              var d = Std.int(Math.max(Math.abs(a.x - pr.x), Math.abs(a.y - pr.y)));
              if (target == null ||
                  d < bestD)
                {
                  target = a;
                  bestD = d;
                }
            }
        }
      // nowhere calm: in here if this area lets the player in, else wait (alertness falls out here)
      if (target == null)
        return find(list, canEnter(pr.currentArea) ? 'enterArea' : 'skipTurn');
      if (target == pr.currentArea)
        return find(list, 'enterArea');
      var x = target.x;
      var y = target.y;
      return {
        kind: 'move',
        label: 'travel ' + x + ',' + y,
        f: function() pr.setTarget(x, y),
      };
    }

// out of the area: Leave Area where the area allows it, else its exit object (a city's sewer hatch),
// learned first and walked to; null when there is no way out from here
  function leave(list: Array<_BotOption>): _BotOption
    {
      var o = first(list, [ 'leaveArea', 'enterSewers', 'learnObject' ]);
      if (o != null)
        return o;
      var exit = nearestObject(game.area.info.exit);
      return (exit != null ? walk(exit.x, exit.y) : null);
    }

// does this area let the player in now, as PlayerRegion.enterAreaAction has it?
  function canEnter(a: game.AreaGame): Bool
    {
      return a.info.canEnter &&
        a.alertness < 75 &&
        !(game.player.state == PLR_STATE_PARASITE &&
          a.info.type == 'corp');
    }

// the improvement the goal policy evolves next: Brain Probe to the level the goals want, any organ
// for EVOLVE_ORGAN, then Microhabitat; null when there is none
  function wantedImprov(): _Improv
    {
      var evo = game.player.evolutionManager;
      if (evo.state == 0)
        return null;
      if (evo.getLevel(IMP_BRAIN_PROBE) < (game.goals.has(GOAL_PROBE_BRAIN_ADVANCED) ? 2 : 1))
        return IMP_BRAIN_PROBE;
      if (game.goals.has(GOAL_EVOLVE_ORGAN))
        for (imp in evo)
          if (imp.info.organ != null)
            return imp.id;
      if (game.goals.has(GOAL_EVOLVE_MICROHABITAT) &&
          evo.getLevel(IMP_MICROHABITAT) == 0)
        return IMP_MICROHABITAT;
      return null;
    }

// does this AI carry a computer device, and know computers while the parasite does not?
  function computerHost(ai: ai.AI): Bool
    {
      return (ai.inventory.has('smartphone') ||
        ai.inventory.has('laptop')) &&
        (game.player.skills.getLevel(SKILL_COMPUTER) > 0 ||
         ai.skills.getLevel(SKILL_COMPUTER) > 0);
    }

// is the host ready to search for the computer goal: a known device, and the computer skill?
  function computerReady(): Bool
    {
      var p = game.player;
      if (!game.goals.has(GOAL_USE_COMPUTER) ||
          p.state != PLR_STATE_HOST ||
          p.skills.getLevel(SKILL_COMPUTER) == 0)
        return false;
      for (id in [ 'smartphone', 'laptop' ])
        if (p.host.inventory.has(id) &&
            p.knowsItem(id))
          return true;
      return false;
    }

// do the timeline goals want clues?
  function wantsClues(): Bool
    {
      return game.goals.has(GOAL_LEARN_CLUE) ||
        game.goals.has(GOAL_LEARN_NPC);
    }

// the area of an event whose location the player knows, while a timeline goal wants one; else null
  function eventArea(): game.AreaGame
    {
      if (!game.goals.has(GOAL_TRAVEL_EVENT) &&
          !wantsClues())
        return null;
      for (e in game.timeline)
        if (!e.isHidden &&
            e.locationKnown &&
            e.location != null)
          return e.location.area;
      return null;
    }

// the option with this id, or null
  function find(list: Array<_BotOption>, id: String): _BotOption
    {
      for (o in list)
        if (o.id == id)
          return o;
      return null;
    }

// the first of these ids on offer, in this order, or null
  function first(list: Array<_BotOption>, ids: Array<String>): _BotOption
    {
      for (id in ids)
        {
          var o = find(list, id);
          if (o != null)
            return o;
        }
      return null;
    }

// walk to a cell as a mouse click does (PlayerArea.setPath takes the first step); a cell with no
// path to it, the cell the player stands on, or a first step refused, is noted, so the goal policy
// does not ask for it again straight away
  function walk(x: Int, y: Int): _BotOption
    {
      return {
        kind: 'move',
        label: 'walk ' + x + ',' + y,
        f: function() {
          var pa = game.playerArea;
          if ((pa.x == x &&
               pa.y == y) ||
              game.area.getPath(pa.x, pa.y, x, y) == null)
            {
              walkFailed = true;
              return;
            }
          // a first step refused (a door, someone in the way) drops the path with no turn passed
          var turns = game.turns;
          pa.setPath(x, y);
          if (pa.path == null &&
              game.turns == turns)
            walkFailed = true;
        },
      };
    }

// the nearest living, unarmed AI to the player that is not its host; only humans when asked, and
// only the ones `want` accepts when given
  function nearestAI(humanOnly: Bool, ?want: ai.AI -> Bool): ai.AI
    {
      var pa = game.playerArea;
      var best: ai.AI = null;
      var bestD = 0;
      for (ai in game.area.getAIinRadius(pa.x, pa.y, 25, false))
        {
          // the armed ones (police, security, soldiers) shoot an attached parasite dead
          if (ai.state == AI_STATE_DEAD ||
              ai == game.player.host ||
              ai.isAggressive ||
              (humanOnly &&
               !ai.isHuman) ||
              (want != null &&
               !want(ai)))
            continue;
          // an alerted AI tears the parasite away: a calm one counts as ten cells closer. every
          // witness around it, who would call the police, as three cells further
          var d = Std.int(Math.max(Math.abs(ai.x - pa.x), Math.abs(ai.y - pa.y))) +
            (ai.state == AI_STATE_IDLE ? 0 : 10) +
            3 * (game.area.getAIinRadius(ai.x, ai.y, 5, false).length - 1);
          if (best == null ||
              d < bestD)
            {
              best = ai;
              bestD = d;
            }
        }
      return best;
    }

// the nearest area object of a type
  function nearestObject(type: String): objects.AreaObject
    {
      var pa = game.playerArea;
      var best: objects.AreaObject = null;
      var bestD = 0;
      var it = game.area.getObjects();
      while (it.hasNext())
        {
          var o = it.next();
          if (o.type != type)
            continue;
          var d = Std.int(Math.max(Math.abs(o.x - pa.x), Math.abs(o.y - pa.y)));
          if (best == null ||
              d < bestD)
            {
              best = o;
              bestD = d;
            }
        }
      return best;
    }

// the random policy: a kind by weight among those on offer, then one option of it uniformly
  function pick(list: Array<_BotOption>): _BotOption
    {
      var kinds = [];
      var total = 0;
      for (o in list)
        if (kinds.indexOf(o.kind) < 0)
          {
            kinds.push(o.kind);
            total += WEIGHTS[o.kind];
          }
      var r = gen.Rng.int(rng, total);
      var kind = kinds[0];
      for (k in kinds)
        {
          r -= WEIGHTS[k];
          if (r < 0)
            {
              kind = k;
              break;
            }
        }
      var of = [ for (o in list) if (o.kind == kind) o ];
      return of[gen.Rng.int(rng, of.length)];
    }

// the invariants the game state should hold between any two steps; one line per broken one
  public function check(): Array<String>
    {
      var list = [];
      var p = game.player;
      // an Int field is a JS number underneath and can hold NaN all the same
      var nan = function(name: String, v: Float)
        {
          if (Math.isNaN(v))
            list.push(name + ' is NaN');
        };
      nan('player.health', p.health);
      nan('player.energy', p.energy);
      nan('player.ap', game.playerArea.ap);
      nan('group.priority', game.group.priority);
      for (c in game.cults)
        {
          nan('cult ' + c.id + ' resources.money', c.resources.money);
          nan('cult ' + c.id + ' power.money', c.power.money);
        }
      if (p.state == PLR_STATE_HOST &&
          p.host == null)
        list.push('host state with no host');
      if (game.location == LOCATION_AREA)
        {
          var a = game.area;
          if (a == null)
            list.push('area location with no area');
          else
            {
              if (game.playerArea.x < 0 ||
                  game.playerArea.y < 0 ||
                  game.playerArea.x >= a.width ||
                  game.playerArea.y >= a.height)
                list.push('player at ' + game.playerArea.x + ',' + game.playerArea.y +
                  ' outside the ' + a.width + 'x' + a.height + ' area');
              if (Math.isNaN(a.alertness))
                list.push('area alertness is NaN');
            }
        }
      for (g in game.goals.iteratorCurrent())
        if (game.goals.completed(g))
          list.push('goal ' + g + ' both current and completed');
      return list;
    }
}
