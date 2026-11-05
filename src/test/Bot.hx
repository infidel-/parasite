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

  public function new(g: Game, seed: Int)
    {
      game = g;
      rng = gen.Rng.mulberry32(seed);
      trail = [];
    }

// pick one option and do it; false when there is nothing left to do
  public function step(): Bool
    {
      var list = options();
      if (list.length == 0)
        return false;
      var o = pick(list);
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
      };
    }

// press Escape through the real keyboard handler
  function escape(): _BotOption
    {
      return {
        kind: 'escape',
        label: 'escape',
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
