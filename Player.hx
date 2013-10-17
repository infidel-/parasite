// player state

import entities.PlayerEntity;
 
class Player
{
  var game: Game; // game state link

  public var entity: PlayerEntity; // player ui entity
  public var intent: String; // action on frobbing AI
  public var state: String; // player state - parasite, attach, host
  public var x: Int; // x,y on map grid
  public var y: Int;
  public var ap: Int; // player action points (2 per turn)
  public var actionList: List<String>; // list of currently available actions

  // state "parasite"
  public var parasiteNoHostTimer: Int; // amount of turns parasite will survive without a host

  // state "attach"
  public var attachHost: AI; // potential host
  public var attachHold: Int; // hold strength

  // state "host"
  public var host: AI; // invaded host
  public var hostTimer: Int; // amount of turns host has left to live
  public var hostControl: Int; // amount of turns until you lose control of the host


  public function new(g: Game, vx: Int, vy: Int)
    {
      game = g;

      x = vx;
      y = vy;
      intent = INTENT_ATTACH;
      state = STATE_PARASITE;
      actionList = new List<String>();
      ap = 2;

      parasiteNoHostTimer = NO_HOST_TURNS;
      attachHold = 0;
      hostTimer = 0;
      hostControl = 0;
    }


// create player entity
  public inline function createEntity()
    {
      entity = new PlayerEntity(game, x, y);
      game.scene.add(entity);
    }


// end of turn for player
  public function turn()
    {
      // state: parasite
      if (state == STATE_PARASITE)
        {
          // "no host" timer
          parasiteNoHostTimer--;
          if (state == STATE_PARASITE && parasiteNoHostTimer == 0)
            {
              game.finish('lose', 'noHost');
              return;
            }
        }

      // state: host (host lifetime timer)
      if (state == STATE_HOST)
        {
          hostTimer--;
          if (hostTimer == 0)
            {
              onHostDeath();

              log('Your host has expired. You have to find a new one.');
            }
        }

      // state: host (we might lose it with host timer earlier)
      if (state == STATE_HOST)
        {
          hostControl--;
          if (hostControl == 0)
            {
              // add AI back to map and clear host var
              host.setPosition(x, y);
              game.map.addAI(host);

              onDetach();

              game.log("You've lost control of the host.");
            }
        }

      ap = 2;
    }


// ==============================   ACTIONS   =======================================


// frob the AI - use current intent (possess, attack, etc)
  public function frobAI(ai: AI)
    {
      if (intent == INTENT_NOTHING || intent == INTENT_DETACH)
        return;

      // intent: attach to new host
      else if (intent == INTENT_ATTACH)
       actionAttachToHost(ai);

      // update HUD info
      game.updateHUD();
    }


// action: attach to host
  public function actionAttachToHost(ai: AI)
    {
      // move to the same spot as AI
      moveTo(ai.x, ai.y);

      // set starting attach parameters
      state = STATE_ATTACHED;
      intent = INTENT_DETACH;
      attachHost = ai;
      attachHold = ATTACH_HOLD_BASE;

      game.log('You have managed to attach to a host.');

      ai.onAttach(); // callback to AI
    }


// action: harden grip when attached to host
  public function actionHardenGrip()
    {
      game.log('You harden your grip on the host.');
      attachHold += 10;
    }


// action: try to invade this AI host
  public function actionInvadeHost()
    {
//      game.log('You attempt to invade the host.');
//      if (Std.random(100) < )
      game.log('You are now in control of the host.');

      // save AI link and remove it from map
      host = attachHost;
      host.parasiteAttached = false;
      hostTimer = host.hostExpiryTurns;
      hostControl = HOST_CONTROL_BASE;
      game.map.destroyAI(host);

      // change image
      entity.setImage(host.entity.getImage(), host.entity.atlasRow);
      entity.setMask(Const.FRAME_MASK_POSSESSED, host.entity.atlasRow);

      // set intent/state
      intent = INTENT_NOTHING;
      state = STATE_HOST;
    }


// action: try to leave this AI host
  public function actionLeaveHost()
    {
      // add AI back to map and clear host var
      host.setPosition(x, y);
      game.map.addAI(host);

      onDetach();

      game.log('You release the host.');
    }


// action: remove attached parasite from host
  public function actionDetach()
    {
      attachHost.parasiteAttached = false;
      onDetach();

      game.log('You detach from the potential host.');
    }


// move player by dx, dy
// returns true on success
  public function moveBy(dx: Int, dy: Int): Bool
    {
      if (state == STATE_ATTACHED)
        actionDetach();

      var nx = x + dx;
      var ny = y + dy;

      if (!game.map.isWalkable(nx, ny))
        return false;

      x = nx;
      y = ny;

      entity.updatePosition();

      postAction(); // post-action call

      // update HUD info
      game.updateHUD();

      // update AI visibility to player
      game.map.updateVisibility();

      return true;
    }


// move player to x, y
// returns true on success
  public function moveTo(nx: Int, ny: Int): Bool
    {
      if (!game.map.isWalkable(nx, ny))
        return false;

      x = nx;
      y = ny;

      entity.updatePosition();

      // update cell visibility to player
      game.map.updateVisibility();

      return true;
    }


// do a player action
  public function action(index: Int)
    {
      // find action name by index
      var i = 1;
      var actionName = null;
      for (a in actionList)
        if (i++ == index)
          {
            actionName = a;
            break;
          }
      if (actionName == null)
        return;

      // harden grip on the victim
      if (actionName == 'hardenGrip')
        actionHardenGrip();

      // invade host 
      else if (actionName == 'invadeHost')
        actionInvadeHost();

      // try to leave current host
      else if (actionName == 'leaveHost')
        actionLeaveHost();

      postAction(); // post-action call

      // update HUD info
      game.updateHUD();
    }


// post-action call: remove AP and new turn
  function postAction()
    {
      // remove 1 AP
      ap--;
      if (ap > 0)
        return;

      // new turn
      game.endTurn();
    }


// update player actions list
  public function updateActionsList()
    {
      actionList.clear();

      // parasite is attached to host
      if (state == STATE_ATTACHED)
        {
          actionList.add('hardenGrip');
          if (attachHold >= 90)
            actionList.add('invadeHost');
        }

      // parasite in control of host
      else if (state == STATE_HOST)
        {
          actionList.add('accessMemory');
          actionList.add('leaveHost');
        }
    }


// ================================ EVENTS =========================================


// event: parasite detached from AI 
  public function onDetach()
    {
      // change image
      entity.setImage(Const.FRAME_DEFAULT, Const.ROW_PARASITE);
      entity.setMask(Const.FRAME_EMPTY);

      // change intent
      intent = INTENT_ATTACH;
      state = STATE_PARASITE;

      // reset no host timer
      parasiteNoHostTimer = NO_HOST_TURNS;
      attachHost = null;
      host = null;
    }


// event: host expired
  public function onHostDeath()
    {
      game.map.createObject(x, y, 'body', host.type);

      onDetach();
    }


// =================================================================================


// log
  public inline function log(s: String)
    {
      game.log(s);
    }


// =================================================================================


  // player states
  public static var STATE_PARASITE = 'parasite';
  public static var STATE_ATTACHED = 'attached';
  public static var STATE_HOST = 'host';

  // player intents
  public static var INTENT_ATTACH = 'attachHost';
  public static var INTENT_DETACH = 'detach';
  public static var INTENT_NOTHING = 'doNothing';

  // amount of turns parasite will survive without a host
  public static var NO_HOST_TURNS = 10;

  // base amount of turns the host has to live
//  public static var HOST_EXPIRY_TURNS = 10;

  // base hold on attach to host
  public static var ATTACH_HOLD_BASE = 10;

  // base control on invade
  public static var HOST_CONTROL_BASE = 10;
}


// player action type

typedef PlayerAction =
{
  var id: String; // action id
  var name: String; // action name
  var ap: Int; // action points cost
}
