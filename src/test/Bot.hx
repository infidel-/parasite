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
import region.RegionObject;

typedef _BotOption = {
  var kind: String; // move, act, window, escape, answer: what the random policy weighs
  var label: String; // what it does, for the trail
  var f: Void -> Void; // do it
  @:optional var id: String; // the action id behind it, for the goal policy to look for
  @:optional var action: _PlayerAction; // the HUD action behind it (its item and object)
}

class Bot
{
  // event NPC types that carry a gun: a bare parasite attaching to one was shot, run after run
  // (every NPC of the start event is an agent), so the hunt leaves them be
  static var ARMED_NPC = [ 'agent', 'soldier', 'police' ];
  // how often the random policy picks each kind, when the kind is on offer at all
  static var WEIGHTS = [
    'move' => 45,
    'act' => 35,
    'window' => 8,
    'escape' => 12,
    'answer' => 100,
  ];
  static inline var TRAIL = 30;
  // the endgame goals, the order they come in: the ship stolen and boarded, the mission, back aboard
  static var ENDGAME: Array<_Goal> = [
    SCENARIO_ALIEN_STEAL_SHIP,
    SCENARIO_ALIEN_ENTER_SHIP,
    SCENARIO_ALIEN_MISSION_ABDUCTION,
    SCENARIO_ALIEN_MISSION_LIQUIDATION,
    SCENARIO_ALIEN_MISSION_INTEL,
    SCENARIO_ALIEN_MISSION_ABDUCTION_GO_SPACESHIP,
    SCENARIO_ALIEN_MISSION_SUCCESS_GO_SPACESHIP,
    SCENARIO_ALIEN_MISSION_FAILURE_GO_SPACESHIP,
  ];
  // the area alertness the goal policy leaves an area at, before the police it calls in arrive
  static inline var FLEE = 50;
  // the parasite energy it stops hardening a grip at and invades early
  static inline var LOW_ENERGY = 15;
  // the host energy a trip on the region map needs; below it the host is changed first
  static inline var TRIP_ENERGY = 50;

  var game: Game;
  var rng: Void -> Float;
  public var trail: Array<String>; // the last TRAIL steps taken, newest last
  public var policy: String; // random, goal (the tutorial, the timeline, the habitat, the endgame), or cult (ordeals and profane missions); random where it has no say
  var walkFailed = false; // the goal policy's last walk had no path: hand the next step to random
  var fled: game.AreaGame = null; // the area the goal policy last fled, not to be entered again straight away
  var opened = ''; // the window the goal policy last opened, and the turn it did (one try a turn each)
  var openedTurn = -1;
  var lastMessage: _LogMessage = null; // the newest log line check() has looked at
  var talkTo: ai.AI = null; // the AI the goal policy is out to chat with (the converse menu picks it)
  var cultTried: Map<String, Int> = new Map(); // the Cult window actions the cult policy tried, and the turn it did
  var startsOrdeals: Bool; // the cult policy starts communal ordeals on odd seeds; they lock the free members a profane ordeal needs, so even seeds leave them be
  var leftTurn = -1; // the turn the policy last tried to leave an area (an area may refuse, and a refusal passes no turn)

  public function new(g: Game, seed: Int, policy: String)
    {
      game = g;
      startsOrdeals = (seed % 2 == 1);
      rng = gen.Rng.mulberry32(seed);
      trail = [];
      this.policy = policy;
      // the log a save brought in was written before this bot: its lines are not checked
      lastMessage = game.messageList.last();
    }

// seed Math.random for a game about to start, and clear what the last game left behind, so a seed
// is the same game whatever ran before it: the headless runs and `bot seed` both start here.
// Std.random compiles to Math.random, so one stream covers every roll
  public static function seed(g: Game, seed: Int)
    {
      js.Syntax.code("Math.random = {0}", gen.Rng.mulberry32(seed));
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
      var o = (policy == 'goal' ? goal(list) :
        policy == 'cult' ? cultGoal(list) : null);
      // a step a goal policy leaves to chance never leaves the host: that walked a bare parasite
      // into a lab's guards, the way the timeline past the computer went on
      if (o == null)
        {
          var rest = (policy == 'random' ? list : [ for (x in list) if (x.id != 'leaveHost') x ]);
          o = pick(rest.length > 0 ? rest : list);
        }
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

      // targeting takes only its own keys (UI.handleTargetingKey): rotate, confirm, Escape
      if (ui.hud.state == HUD_TARGETING)
        {
          for (code in [ 'Numpad4', 'Numpad6', 'Enter' ])
            list.push(press('target ' + code, code, '', false));
          list.push(escape());
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
            action: a,
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

      // the random policy aims too: T enters targeting (on key up, as UI.onKeyUp has it), and a target
      // set is shot (s) or hit (a). The goal policy has no use for it yet
      if (policy == 'random' &&
          ui.hud.state == HUD_DEFAULT &&
          game.location == LOCATION_AREA &&
          game.player.state == PLR_STATE_HOST)
        {
          list.push(press('key t target', 'KeyT', 't', true));
          if (ui.hud.targeting.canShootTarget())
            list.push(press('key s shoot target', 'KeyS', 's', false));
          if (ui.hud.targeting.canAttackTarget())
            list.push(press('key a hit target', 'KeyA', 'a', false));
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
          case UISTATE_DIFFICULTY:
            // config.difficulty 0 asks: noob, easy, normal, hard (ui.Difficulty.action)
            for (i in 0...4)
              list.push({
                kind: 'answer',
                label: 'difficulty ' + i,
                f: function() w.action(i),
              });
          case UISTATE_OVUM:
            w.update();
            var actions = @:privateAccess (cast w: ui.Ovum).listActions;
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
                  action: actions[i],
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
      var o = press('escape', 'Escape', 'Escape', false);
      o.kind = 'escape';
      o.id = 'escape';
      return o;
    }

// press a key through the real keyboard handler: UI.onKey, or UI.onKeyUp for a key that acts on
// release
  function press(label: String, code: String, key: String, up: Bool): _BotOption
    {
      var e: js.html.KeyboardEvent = cast {
        key: key,
        code: code,
        keyCode: (code == 'Escape' ? 27 : 0),
        altKey: false,
        ctrlKey: false,
        shiftKey: false,
        preventDefault: function() {},
      };
      return {
        kind: 'act',
        label: label,
        f: function() {
          if (up)
            @:privateAccess game.ui.onKeyUp(e);
          else @:privateAccess game.ui.onKey(e);
        },
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
                  wantsSearch() &&
                  game.area.isHabitat)))
              return o;
          return find(list, 'escape');
        }
      if (ui.state != UISTATE_DEFAULT)
        return null;
      // a chat under way, or the converse menu open to start one
      if (ui.hud.state == HUD_CHAT)
        return chat(list);
      if (ui.hud.state == HUD_CONVERSE_MENU)
        {
          for (o in list)
            if (o.id == 'converseMenu.chat' &&
                o.action.obj == talkTo)
              return o;
          return find(list, 'escape');
        }
      // a pickup submenu opened on the way: take the ship part or the clue paper it was opened for,
      // or go back
      if (ui.hud.state == HUD_PICKUP_MENU)
        {
          for (o in list)
            if (o.id == 'get' &&
                ((cast o.action.obj: objects.Pickup).item.id == 'shipPart' ||
                 ((cast o.action.obj: objects.Pickup).item.id == 'paper' &&
                  wantsClues())))
              return o;
          return find(list, 'pickupMenu.abort');
        }
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
      // the endgame, once the ship is found: its own policy, and the targeting it needs
      var eg = endgameGoal();
      if (eg != null &&
          game.location == LOCATION_AREA)
        {
          var o = endgame(list, eg);
          if (o != null)
            return o;
        }

      // the computer goal wants a host carrying a device, and one who knows computers while the
      // parasite does not
      var human = (wantsSearch() ?
        nearestAI(true, computerHost) : nearestAI(true));
      if (human == null)
        human = nearestAI(true);
      // the NPC hunted down, once it has spawned here
      var wanted = npcTarget();
      if (wanted != null &&
          wanted.ai != null &&
          wanted.ai.state != AI_STATE_DEAD &&
          game.area.getAIByID(wanted.ai.id) == wanted.ai)
        human = wanted.ai;
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
          // a habitat keeps a bare parasite alive, with no one to take: out to find a host
          if (ai == null &&
              game.area.isHabitat)
            return leave(list);
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
          wantsSearch())
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
          // a paper on a desk is picked up from beside it (Document.canActivateNear): nobody stands
          // on a desk, so a walk onto it fails
          if (host.inventory.length() < host.maxItems)
            for (doc in game.area.getObjects())
              if (doc.type == 'document' &&
                  doc.item.id == 'paper')
                {
                  var o = (game.area.isWalkable(doc.x, doc.y) ? walk(doc.x, doc.y) : walkNear(doc.x, doc.y));
                  if (o != null)
                    return o;
                }
          // no paper about: off to a clue spot, as a lab or base lays new ones only on spots on
          // screen and out of sight (AreaGame.turnSpawnClues), and a bot standing still got none
          var pts = [ for (pt in game.area.clueSpawnPoints) if (guardFree(pt.x, pt.y)) pt ];
          if (pts.length == 0)
            pts = game.area.clueSpawnPoints;
          if (pts.length > 0)
            {
              // clue spots are desk and bench cells too
              var pt = pts[gen.Rng.int(rng, pts.length)];
              var o = walkNear(pt.x, pt.y);
              if (o != null)
                return o;
            }
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
           (wantsSearch() &&
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
          (wantsSearch() &&
           !computerHost(host) &&
           human != null &&
           computerHost(human)) ||
          (wanted != null &&
           human == wanted.ai &&
           host != human))
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
      // the endgame's area, with a host: the corp area of the mission takes no bare parasite
      var eg = endgameGoal();
      if (eg != null &&
          game.player.state == PLR_STATE_HOST)
        {
          var a = endgameArea(eg);
          if (a == pr.currentArea)
            return find(list, canEnter(a) ? 'enterArea' : 'skipTurn');
          var x = a.x;
          var y = a.y;
          return {
            kind: 'move',
            label: 'travel ' + x + ',' + y + ' (endgame)',
            f: function() pr.setTarget(x, y),
          };
        }
      // a habitat is made in the sewers under the first inhabited area it gets to
      var o = find(list, 'createHabitat');
      if (o != null &&
          game.goals.has(GOAL_CREATE_HABITAT))
        return o;
      // a host ready for the computer goal goes to the habitat
      if (wantsSearch() &&
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
      // a bare parasite too weak for a region step (PlayerRegion.moveAction) tries the area it is over
      if (p.state == PLR_STATE_PARASITE &&
          p.energy < p.vars.regionEnergyPerTurn)
        return find(list, canEnter(pr.currentArea) ? 'enterArea' : 'skipTurn');
      var x = target.x;
      var y = target.y;
      return {
        kind: 'move',
        label: 'travel ' + x + ',' + y,
        f: function() pr.setTarget(x, y),
      };
    }

// the endgame goal held now, or null
  function endgameGoal(): _Goal
    {
      for (g in ENDGAME)
        if (game.goals.has(g))
          return g;
      return null;
    }

// the area an endgame goal is worked in: the lab the ship is studied in, the corp area of the
// mission, or where the ship hides
  function endgameArea(g: _Goal): game.AreaGame
    {
      var ship = @:privateAccess scenario.GoalsAlienCrashLanding.getSpaceshipState(game);
      if (g == SCENARIO_ALIEN_STEAL_SHIP)
        return game.region.get(ship.studyAreaID);
      if (g == SCENARIO_ALIEN_MISSION_ABDUCTION ||
          g == SCENARIO_ALIEN_MISSION_LIQUIDATION ||
          g == SCENARIO_ALIEN_MISSION_INTEL)
        return game.region.get(scenario.GoalsAlienCrashLanding.getMissionState(game).areaID);
      return game.region.get(ship.hiddenAreaID);
    }

// the endgame in an area: each ship part into its own slot and the startup, then the ship boarded,
// the mission target invaded, probed or killed, and back aboard. null leaves the step to the rest
// of the goal policy (a host found, a window, an upkeep)
  function endgame(list: Array<_BotOption>, g: _Goal): _BotOption
    {
      var p = game.player;
      var pa = game.playerArea;
      var area = endgameArea(g);
      if (game.area != area)
        return (p.state == PLR_STATE_HOST ? leave(list) : null);
      var ship = @:privateAccess scenario.GoalsAlienCrashLanding.getSpaceshipState(game);

      // the ship in the lab
      if (g == SCENARIO_ALIEN_STEAL_SHIP)
        {
          if (p.state != PLR_STATE_HOST)
            return null;
          var names = [ ship.part1Name, ship.part2Name, ship.part3Name ];
          var done = [ ship.part1Installed, ship.part2Installed, ship.part3Installed ];
          var slots = [ ship.slot1ObjectID, ship.slot2ObjectID, ship.slot3ObjectID ];
          // a part the host carries goes into its own slot
          for (i in 0...3)
            if (!done[i])
              for (item in p.host.inventory)
                if (item.id == 'shipPart' &&
                    item.name == names[i])
                  {
                    for (o in list)
                      if (o.id == 'installPart' &&
                          o.action.item == item &&
                          o.action.obj.id == slots[i])
                        return o;
                    var slot = game.area.getObject(slots[i]);
                    return walkNear(slot.x, slot.y);
                  }
          // the next part not installed yet, picked up where it lies (beside a lab table too)
          for (i in 0...3)
            if (!done[i])
              for (o in game.area.getObjects())
                if (o.type == 'pickup' &&
                    o.item.id == 'shipPart' &&
                    o.item.name == names[i])
                  {
                    for (x in list)
                      if (x.id == 'get' &&
                          x.action.obj == o)
                        return x;
                    var x = first(list, [ 'pickupMenu', 'learnObject' ]);
                    if (x != null &&
                        Math.max(Math.abs(o.x - pa.x), Math.abs(o.y - pa.y)) <= 1)
                      return x;
                    return walkNear(o.x, o.y);
                  }
          if (done[0] &&
              done[1] &&
              done[2])
            {
              var o = find(list, 'startShip');
              if (o != null)
                return o;
              var console = game.area.getObject(ship.studyObjectID);
              return walkNear(console.x, console.y);
            }
          return null;
        }

      // the mission target, while a mission wants it
      if (g == SCENARIO_ALIEN_MISSION_ABDUCTION ||
          g == SCENARIO_ALIEN_MISSION_LIQUIDATION ||
          g == SCENARIO_ALIEN_MISSION_INTEL)
        return mission(list, g);

      // aboard: the ship where it hides, boarded with or without the target (the abduction keeps it)
      var o = find(list, 'enterShip');
      if (o != null)
        return o;
      var obj = game.area.getObject(ship.hiddenObjectID);
      return (p.state == PLR_STATE_HOST ? walkNear(obj.x, obj.y) : null);
    }

// the mission in the corp area: a smiler's keycard through the locked office door, then the target
// invaded (abduction; intel probes it too), or killed (liquidation)
  function mission(list: Array<_BotOption>, g: _Goal): _BotOption
    {
      var p = game.player;
      var pa = game.playerArea;
      var npcID = scenario.GoalsAlienCrashLanding.getMissionState(game).npcID;
      var target: ai.AI = null;
      for (x in @:privateAccess game.area._ai)
        if (x.npc != null &&
            x.npc.id == npcID &&
            x.state != AI_STATE_DEAD)
          target = x;
      if (target == null)
        return null;
      var near = (Math.max(Math.abs(target.x - pa.x), Math.abs(target.y - pa.y)) <= 1);
      // a known keycard of the office lock, or a smiler carrying one to ride to
      var card = false;
      if (p.state == PLR_STATE_HOST)
        for (item in p.host.inventory.getAll('keycard'))
          if (item.lockID == 'corp-mission')
            {
              // learned first: an unknown card opens nothing (objects.Door)
              if (!p.knowsItem(item.id))
                return openOnce(list, _UIState.UISTATE_BODY);
              card = true;
            }
      // a smiler pulls a parasite back until it is talked round to full consent
      var smiler: ai.AI = null;
      if (!card)
        for (x in @:privateAccess game.area._ai)
          if (x.type == 'smiler' &&
              x.state != AI_STATE_DEAD &&
              x != p.host &&
              x.inventory.getAll('keycard').length > 0)
            smiler = x;
      switch (p.state)
        {
          case PLR_STATE_PARASITE:
            // onto the target, or onto a won-over smiler first while the office is locked to us
            var want = (smiler != null ? smiler : target);
            if (g == SCENARIO_ALIEN_MISSION_LIQUIDATION &&
                smiler == null)
              want = null;
            if (want == null ||
                (want == smiler &&
                 smiler.chat.consent < 100))
              return null;
            if (pa.x == want.x &&
                pa.y == want.y)
              return find(list, 'attachHost');
            return walk(want.x, want.y);
          case PLR_STATE_ATTACHED:
            return null;
          default:
        }
      // in the target: intel probes it, the abduction is done by holding it
      if (p.host == target)
        return (g == SCENARIO_ALIEN_MISSION_INTEL ? find(list, 'probeBrain') : find(list, 'skipTurn'));
      // no card: the smiler that carries one talked round, then stepped into
      if (smiler != null)
        {
          var beside = (Math.max(Math.abs(smiler.x - pa.x), Math.abs(smiler.y - pa.y)) <= 1);
          if (smiler.chat.consent >= 100)
            return (beside ? find(list, 'leaveHost') : walkNear(smiler.x, smiler.y));
          return talk(list, smiler);
        }
      if (!near)
        return walkNear(target.x, target.y);
      if (g != SCENARIO_ALIEN_MISSION_LIQUIDATION)
        return find(list, 'leaveHost');
      return attack(list, target);
    }

// talk an AI round to full consent, the way a player does: the host first (a chat takes a host at
// 75 affinity and full consent, game.Chat.addConverseAction), then the AI, from beside it
  function talk(list: Array<_BotOption>, ai: ai.AI): _BotOption
    {
      var p = game.player;
      var pa = game.playerArea;
      if (p.host.affinity < 75)
        return find(list, 'skipTurn');
      // a chat just over leaves a timeout on the one talked to (game.Chat.start refuses)
      if (p.host.chat.consent < 100)
        return find(list, (p.host.chat.timeout > 0 ? 'skipTurn' : 'converseHost'));
      if (Math.max(Math.abs(ai.x - pa.x), Math.abs(ai.y - pa.y)) > 1)
        return walkNear(ai.x, ai.y);
      if (ai.chat.timeout > 0)
        return find(list, 'skipTurn');
      talkTo = ai;
      return find(list, 'converseMenu');
    }

// the cult policy: the Cult window worked (a running ordeal funded, else a new one started), cult
// turns waited out (one in ten turns), and each profane mission taken to its area and done: a
// Persuade target talked round, a Kill target hit. Hosts are kept the goal policy's way
  function cultGoal(list: Array<_BotOption>): _BotOption
    {
      var ui = game.ui;
      var p = game.player;
      for (o in list)
        if (o.kind == 'answer')
          return o;
      // the window: each action once a turn, the funding first, then whatever starts an ordeal
      if (ui.state == UISTATE_CULT)
        {
          var best: _BotOption = null;
          var rank = 99;
          // a submenu's choices can share their parent's id (recruit, then the power to recruit for)
          var key = function(o: _BotOption) return o.id + ':' + (o.action != null ? o.action.name : '');
          for (o in list)
            {
              if (o.id == null ||
                  cultTried[key(o)] == game.turns)
                continue;
              var r = (StringTools.startsWith(o.id, 'spend.') ? 0 :
                StringTools.startsWith(o.id, 'ordeal_') ? 1 :
                o.id == 'initiateOrdeal' ? (startsOrdeals ? 2 : 99) :
                // a submenu with nothing to do goes back up, to the menus not tried yet
                o.id == 'back' ? 50 :
                // followers called in are not free for the profane ordeals
                (o.id == 'escape' ||
                 o.id == 'callHelp' ||
                 o.id == 'annul' ||
                 o.id == 'callMember' ||
                 o.id == 'trade' ||
                 o.id == 'tradeResources' ||
                 o.id == 'bazaar') ? 99 : 3);
              if (r < rank)
                {
                  best = o;
                  rank = r;
                }
            }
          if (best == null)
            return find(list, 'escape');
          cultTried[key(best)] = game.turns;
          return best;
        }
      if (ui.state != UISTATE_DEFAULT)
        return null;
      if (ui.hud.state == HUD_CHAT)
        return chat(list);
      if (ui.hud.state == HUD_CONVERSE_MENU)
        {
          for (o in list)
            if (o.id == 'converseMenu.chat' &&
                o.action.obj == talkTo)
              return o;
          return find(list, 'escape');
        }
      // Forma is left with its own key: Escape opens the main menu over it
      if (ui.hud.state == HUD_BASE_BUILDING)
        return first(list, [ 'baseExit', 'escape' ]);
      if (ui.hud.state != HUD_DEFAULT)
        return find(list, 'escape');
      // the profane mission open, if any, with its marker on the region map to travel to: an area of
      // the map, or the habitat under one (Ordeals.getMarkerMission), or x,y
      var m: cult.Mission = null;
      var marker: { x: Int, y: Int } = null;
      for (ordeal in game.cults[0].ordeals.list)
        for (x in ordeal.missions)
          if (!x.isCompleted &&
              x.areaID >= 0)
            for (a in game.region)
              // a habitat area is in the list too, off the map at -1,-1
              if (a.x >= 0 &&
                  (a.id == x.markerAreaID ||
                   (a.hasHabitat &&
                    a.habitatAreaID == x.markerAreaID) ||
                   (x.markerAreaID < 0 &&
                    a.x == x.x &&
                    a.y == x.y)))
                {
                  m = x;
                  marker = { x: a.x, y: a.y };
                }
      if (game.location == LOCATION_REGION)
        {
          if (m == null ||
              p.state != PLR_STATE_HOST)
            return region(list);
          var o = find(list, 'enterMissionArea');
          if (o != null)
            return o;
          if (game.playerRegion.target != null)
            return {
              kind: 'move',
              label: 'follow region path',
              f: game.update,
            };
          var x = marker.x;
          var y = marker.y;
          return {
            kind: 'move',
            label: 'travel ' + x + ',' + y + ' (mission)',
            f: function() game.playerRegion.setTarget(x, y),
          };
        }
      if (game.location != LOCATION_AREA)
        return null;
      // no host, a host about to expire, a walk under way: the goal policy keeps those
      if (p.state != PLR_STATE_HOST ||
          p.host.energy < 20 ||
          !p.host.isHuman ||
          game.playerArea.path != null ||
          walkFailed)
        return goal(list);
      if (p.hostControl < 50)
        {
          var o = find(list, 'reinforceControl');
          if (o != null)
            return o;
        }
      if (m != null &&
          game.area.id == m.areaID)
        {
          // the mission's target, spawned in its area
          var targetID = (Std.isOfType(m, cult.missions.Persuade) ? (cast m: cult.missions.Persuade).target.id :
            Std.isOfType(m, cult.missions.Kill) ? (cast m: cult.missions.Kill).target.id : -1);
          var target = game.area.getAIByID(targetID);
          if (target == null ||
              target.state == AI_STATE_DEAD)
            return null;
          if (m.type == MISSION_PERSUADE)
            {
              var o = talk(list, target);
              return (o != null ? o : find(list, 'skipTurn'));
            }
          if (Math.max(Math.abs(target.x - game.playerArea.x), Math.abs(target.y - game.playerArea.y)) > 1)
            return walkNear(target.x, target.y);
          return attack(list, target);
        }
      // out to the mission, else the window once a turn, else the cult turn waited for
      if (m != null)
        {
          var o = leave(list);
          if (o != null)
            return o;
        }
      var o = openOnce(list, _UIState.UISTATE_CULT);
      return (o != null ? o : find(list, 'skipTurn'));
    }

// a chat under way: an action that answers the target's need (ChatConst.needActions, what Analyze
// tells the player), else any but the questions, which cost the most; out at full consent
  function chat(list: Array<_BotOption>): _BotOption
    {
      var c = game.player.chat;
      if (c.target == null ||
          c.target.chat.consent >= 100)
        return find(list, 'chat.exit');
      for (a in const.ChatConst.needActions[c.target.chat.needID])
        {
          var o = find(list, 'chat.' + a.toLowerCase());
          if (o != null)
            return o;
        }
      for (o in list)
        if (o.id != null &&
            StringTools.startsWith(o.id, 'chat.') &&
            o.id != 'chat.exit' &&
            o.id != 'chat.question' &&
            o.id != 'chat.consult')
          return o;
      return find(list, 'chat.exit');
    }

// hit an AI next to the host the way the keyboard does: T into targeting, rotate to it, confirm,
// then `a`
  function attack(list: Array<_BotOption>, ai: ai.AI): _BotOption
    {
      var t = game.ui.hud.targeting;
      if (game.ui.hud.state == HUD_TARGETING)
        return press('target ' + ai.id, (t.targetingTarget != null &&
          t.targetingTarget.ai == ai ? 'Enter' : 'Numpad6'), '', false);
      if (t.target != null &&
          t.target.ai == ai &&
          t.canAttackTarget())
        return press('key a hit ' + ai.id, 'KeyA', 'a', false);
      return press('key t target ' + ai.id, 'KeyT', 't', true);
    }

// walk next to a cell the player cannot stand on (a slot, a console, a lab table, an AI): the
// nearest walkable cell beside it; null when the player is beside it already
  function walkNear(x: Int, y: Int): _BotOption
    {
      var pa = game.playerArea;
      if (Math.max(Math.abs(x - pa.x), Math.abs(y - pa.y)) <= 1)
        return null;
      var best = null;
      var bestD = 0;
      for (dy in -1...2)
        for (dx in -1...2)
          {
            var nx = x + dx;
            var ny = y + dy;
            if ((dx == 0 &&
                 dy == 0) ||
                !game.area.isWalkable(nx, ny) ||
                game.area.getAI(nx, ny) != null)
              continue;
            var d = Std.int(Math.max(Math.abs(nx - pa.x), Math.abs(ny - pa.y)));
            if (best == null ||
                d < bestD)
              {
                best = { x: nx, y: ny };
                bestD = d;
              }
          }
      return (best != null ? walk(best.x, best.y) : walk(x, y));
    }

// out of the area: Leave Area where the area allows it, else its exit object (a city's sewer hatch),
// learned first and walked to; null when there is no way out from here
  function leave(list: Array<_BotOption>): _BotOption
    {
      var o = first(list, [ 'leaveArea', 'enterSewers', 'learnObject' ]);
      if (o != null &&
          leftTurn == game.turns)
        return null;
      if (o != null)
        {
          leftTurn = game.turns;
          return o;
        }
      // a habitat lists no exit ('-'): its way out is the hatch object
      var exit = nearestObject(game.area.isHabitat ? 'habitat_exit' : game.area.info.exit);
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
      if (!wantsSearch() ||
          p.state != PLR_STATE_HOST ||
          p.skills.getLevel(SKILL_COMPUTER) == 0)
        return false;
      for (id in [ 'smartphone', 'laptop' ])
        if (p.host.inventory.has(id) &&
            p.knowsItem(id))
          return true;
      return false;
    }

// do the timeline goals want clues? Past the computer goal the timeline wants them until the ship
// is found
  function wantsClues(): Bool
    {
      return game.goals.has(GOAL_LEARN_CLUE) ||
        game.goals.has(GOAL_LEARN_NPC) ||
        game.goals.has(GOAL_PROGRESS_TIMELINE) ||
        game.goals.has(SCENARIO_ALIEN_FIND_SHIP);
    }

// does the goal policy want a computer search: for the computer goal, and past it whenever no
// event NPC is known to hunt down and a search has someone to research (items.Computer refuses
// once every known person is researched, and the bot sat in the habitat for good)
  function wantsSearch(): Bool
    {
      if (game.goals.has(GOAL_USE_COMPUTER))
        return true;
      if (!game.goals.completed(GOAL_USE_COMPUTER) ||
          !wantsClues() ||
          npcTarget() != null)
        return false;
      for (e in game.timeline)
        if (!e.isHidden &&
            e.npcCanResearch())
          return true;
      return false;
    }

// past the computer goal, an event NPC the player knows the job and the area of (so it spawns
// there), alive and not wrung yet; else null
  function npcTarget(): scenario.NPC
    {
      if (!game.goals.completed(GOAL_USE_COMPUTER) ||
          !wantsClues())
        return null;
      // the earliest event placed: an armed NPC is hunted only when it leads past it, where it is the
      // only way on (events 10-8 are agents alone, 10 with no place to read papers in)
      var first = 99;
      for (e in game.timeline)
        if (!e.isHidden &&
            e.locationKnown &&
            e.location != null)
          {
            first = e.index;
            break;
          }
      for (e in game.timeline)
        if (!e.isHidden)
          for (n in e.npc)
            if (n.areaKnown &&
                n.jobKnown &&
                !n.isDead &&
                !n.memoryKnown &&
                !n.noEventClues &&
                (e.index < first ||
                 ARMED_NPC.indexOf(n.type) < 0))
              return n;
      return null;
    }

// the area of an event whose location the player knows, while a timeline goal wants one; else null.
// Past the computer goal, the area of the NPC to hunt down comes first
  function eventArea(): game.AreaGame
    {
      if (!game.goals.has(GOAL_TRAVEL_EVENT) &&
          !wantsClues())
        return null;
      // clues lead one event back at a time, so the earliest event placed is where the next one is
      // learned (its papers, and the events before it that share the place); an NPC of a later
      // event only feeds an event already passed
      var first: scenario.Event = null;
      for (e in game.timeline)
        if (!e.isHidden &&
            e.locationKnown &&
            e.location != null)
          {
            first = e;
            break;
          }
      var n = npcTarget();
      if (n != null &&
          (first == null ||
           n.event.index <= first.index))
        return n.area;
      return (first != null ? first.location.area : null);
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

// a cell no AI within five cells can see: past five an idle AI does not grow alert at the sight of an
// unarmed host (DefaultLogic.playerVisibility), within it each turn adds up to 15, and an alerted
// scientist calls the guards in
  function guardFree(x: Int, y: Int): Bool
    {
      for (ai in @:privateAccess game.area._ai)
        if (ai != game.player.host &&
            Math.max(Math.abs(ai.x - x), Math.abs(ai.y - y)) <= 5 &&
            ai.seesPosition(x, y))
          return false;
      return true;
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
      var pa = game.playerArea;
      if (p.state == PLR_STATE_HOST &&
          p.host == null)
        list.push('host state with no host');
      else if (p.state == PLR_STATE_HOST &&
          p.hostID != p.host.id)
        list.push('hostID ' + p.hostID + ' is not the host ' + p.host.id);
      if (p.state == PLR_STATE_PARASITE &&
          (p.host != null ||
           pa.attachHost != null))
        list.push('parasite state with a host or an attach host');
      if (game.location == LOCATION_AREA)
        {
          var a = game.area;
          if (a == null)
            list.push('area location with no area');
          else
            {
              if (pa.x < 0 ||
                  pa.y < 0 ||
                  pa.x >= a.width ||
                  pa.y >= a.height)
                list.push('player at ' + pa.x + ',' + pa.y +
                  ' outside the ' + a.width + 'x' + a.height + ' area');
              if (Math.isNaN(a.alertness))
                list.push('area alertness is NaN');
              checkArea(a, list);
            }
        }
      for (g in game.goals.iteratorCurrent())
        if (game.goals.completed(g))
          list.push('goal ' + g + ' both current and completed');
      if (game.messageList.length > 100)
        list.push('messageList holds ' + game.messageList.length + ' lines, over its cap of 100');
      checkCounters(list);
      checkLog(list);
      return list;
    }

// the log lines since the last check show no unfilled template: a value missing from a template's
// arguments prints `null` (l10n.Loc), an unparsed one keeps its braces. INFO and DEBUG lines are
// built by hand and may hold braces
  function checkLog(list: Array<String>)
    {
      var fresh = (lastMessage == null);
      for (m in game.messageList)
        {
          if (!fresh)
            {
              fresh = (m == lastMessage);
              continue;
            }
          var text = ~/<[^>]*>/g.replace(m.msg, '');
          if (!StringTools.startsWith(text, 'INFO ') &&
              !StringTools.startsWith(text, 'DEBUG ') &&
              ~/\bnull\b|\bundefined\b|\bNaN\b|\[object |[{}]/.match(text))
            list.push('log line looks unfilled: ' + text);
        }
      // the line looked at last fell off the capped list: everything in it was new
      if (!fresh)
        {
          lastMessage = null;
          checkLog(list);
          return;
        }
      lastMessage = game.messageList.last();
    }

// the current area's invariants: its AIs, the host and the cultists in it
  function checkArea(a: game.AreaGame, list: Array<String>)
    {
      var p = game.player;
      var pa = game.playerArea;
      if (p.state == PLR_STATE_HOST &&
          a.getAIByID(p.host.id) != p.host)
        list.push('host ' + p.host.id + ' is not in the area AI list');
      if (p.state == PLR_STATE_ATTACHED &&
          (pa.attachHost == null ||
           !pa.attachHost.parasiteAttached))
        list.push('attached state with no attach host, or one not flagged parasiteAttached');
      for (ai in @:privateAccess a._ai)
        {
          if (Math.isNaN(ai.health) ||
              Math.isNaN(ai.energy))
            list.push('AI ' + ai.id + ' health or energy is NaN');
          if (ai.health > ai.maxHealth)
            list.push('AI health above max (' + ai.health + ' > ' + ai.maxHealth + ')');
          if (ai.energy > ai.maxEnergy)
            list.push('AI ' + ai.id + (ai == p.host ? ' (host)' : '') + ' energy above max (' + ai.energy + ' > ' + ai.maxEnergy + ')');
          if (ai.x < 0 ||
              ai.y < 0 ||
              ai.x >= a.width ||
              ai.y >= a.height)
            list.push('AI ' + ai.id + ' at ' + ai.x + ',' + ai.y + ' outside the area');
          // a carried host still holds its enemies from the area it came from
          if (ai != p.host)
            for (id in ai.enemies)
              if (a.getAIByID(id) == null)
                {
                  list.push('AI ' + ai.id + ' has enemy ' + id + ', not in the area');
                  break;
                }
          // Cult.onRemoveAI throws on a cultist with no member record (TODO.md)
          if (ai.isCultist)
            {
              var c = game.getCultByID(ai.cultID);
              if (c == null ||
                  c.getMemberByID(ai.id) == null)
                list.push('cultist AI ' + ai.id + ' has no member record in cult ' + ai.cultID);
            }
        }
    }

// the id counters are ahead of every live id, or the next object made takes an id in use (a load
// restores them from the ids it finds)
  function checkCounters(list: Array<String>)
    {
      // the largest live id of each kind, reported once against its counter
      var top = new Map<String, Int>();
      var ahead = function(name: String, id: Int)
        {
          if (!top.exists(name) ||
              id > top[name])
            top[name] = id;
        };
      if (game.region != null)
        for (o in game.region.getObjects())
          ahead('RegionObject', o.id);
      if (game.area != null)
        {
          for (x in @:privateAccess game.area._ai)
            ahead('AIData', x.id);
          for (o in game.area.getObjects())
            ahead('AreaObject', o.id);
        }
      for (e in game.timeline)
        for (npc in e.npc)
          ahead('NPC', npc.id);
      var counters = [
        'RegionObject' => RegionObject._maxID,
        'AIData' => ai.AIData._maxID,
        'AreaObject' => objects.AreaObject._maxID,
        'NPC' => @:privateAccess scenario.NPC._maxID,
      ];
      for (name in top.keys())
        if (top[name] >= counters[name])
          list.push(name + '._maxID ' + counters[name] + ' is not above live id ' + top[name]);
    }
}
