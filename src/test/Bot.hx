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

  var game: Game;
  var rng: Void -> Float;
  public var trail: Array<String>; // the last TRAIL steps taken, newest last
  public var policy: String; // random, or goal: work through the tutorial (random where it has no say)

  public function new(g: Game, seed: Int, policy: String)
    {
      game = g;
      rng = gen.Rng.mulberry32(seed);
      trail = [];
      this.policy = policy;
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
      var probeLevel = (game.goals.has(GOAL_PROBE_BRAIN_ADVANCED) ? 2 : 1);
      if (ui.state == UISTATE_EVOLUTION)
        {
          var o = find(list, 'set.' + _Improv.IMP_BRAIN_PROBE);
          return (o != null &&
            !p.evolutionManager.isActive ? o : find(list, 'escape'));
        }
      // the body window is where an item is learned
      if (ui.state == UISTATE_BODY)
        {
          for (o in list)
            if (o.id != null &&
                StringTools.startsWith(o.id, 'learn.'))
              return o;
          return find(list, 'escape');
        }
      if (ui.state != UISTATE_DEFAULT ||
          game.location != LOCATION_AREA)
        return null;
      // a walk under way goes on, one waypoint a step, as Game.update steps a clicked path
      if (pa.path != null)
        return {
          kind: 'move',
          label: 'follow path',
          f: game.update,
        };

      var human = nearestAI(true);
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
      if (p.state == PLR_STATE_ATTACHED)
        return first(list, [ 'invadeHost', 'hardenGrip', 'invadeEarly' ]);

      // in a host
      var host = p.host;
      if (p.hostControl < 50)
        {
          var o = find(list, 'reinforceControl');
          if (o != null)
            return o;
        }
      var evo = p.evolutionManager;
      if (evo.state > 0 &&
          evo.getLevel(IMP_BRAIN_PROBE) < probeLevel)
        return (evo.isActive ? find(list, 'skipTurn') : find(list, 'open.' + _UIState.UISTATE_EVOLUTION));
      // whatever the host carries, learned (in the body window) before its brain is wrung
      // (a dog's inventory is unavailable there, as ui.Body.updateInventory has it)
      if (p.vars.inventoryEnabled &&
          host.isHuman)
        for (item in host.inventory.withWorn())
          if (!p.knowsItem(item.id))
            return find(list, 'open.' + _UIState.UISTATE_BODY);
      if (game.goals.has(GOAL_ENTER_SEWERS))
        {
          var o = first(list, [ 'enterSewers', 'learnObject' ]);
          if (o != null)
            return o;
          var hatch = nearestObject('sewer_hatch');
          if (hatch != null)
            return walk(hatch.x, hatch.y);
        }
      // a probe takes health off the host: stop while it can still carry the parasite to the next one
      var o = find(list, 'probeBrain');
      if (o != null &&
          host.isHuman &&
          host.health > 3 &&
          !game.goals.completed(GOAL_LEARN_SOCIETY))
        return o;
      // a spent host, or a dog, is a ride to the nearest human: walk it there, step out next to them
      if (!host.isHuman ||
          host.health <= 3 ||
          host.energy < 20 ||
          !game.goals.completed(GOAL_LEARN_SOCIETY))
        {
          if (human == null)
            return null;
          if (Math.max(Math.abs(human.x - pa.x), Math.abs(human.y - pa.y)) <= 1)
            return find(list, 'leaveHost');
          return walk(human.x, human.y);
        }
      return find(list, 'skipTurn');
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

// walk to a cell as a mouse click does (PlayerArea.setPath takes the first step)
  function walk(x: Int, y: Int): _BotOption
    {
      return {
        kind: 'move',
        label: 'walk ' + x + ',' + y,
        f: function() game.playerArea.setPath(x, y),
      };
    }

// the nearest living, unarmed AI to the player that is not its host; only humans when asked
  function nearestAI(humanOnly: Bool): ai.AI
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
               !ai.isHuman))
            continue;
          // an alerted AI tears the parasite away: a calm one counts as ten cells closer
          var d = Std.int(Math.max(Math.abs(ai.x - pa.x), Math.abs(ai.y - pa.y))) +
            (ai.state == AI_STATE_IDLE ? 0 : 10);
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
