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

  public var evolutionManager: EvolutionManager; // main evolution control

  // knowledge
  public var humanSociety(default, set): Float; // knowledge about human society (0-99.9%)

  // state-independent
  public var energy(default, set): Int; // energy left
  public var maxEnergy: Int; // max energy
  public var chemicals: Array<Int>; // chemical compounds
  public var maxChemicals: Array<Int>; // max chemical compounds

  // state "parasite"

  // state "attach"
  public var attachHost: AI; // potential host
  public var attachHold(default, set): Int; // hold strength

  // state "host"
  public var host: AI; // invaded host
  public var hostTimer(default, set): Int; // amount of turns host has left to live
  public var hostControl(default, set): Int; // amount of turns until you lose control of the host


  public function new(g: Game, vx: Int, vy: Int)
    {
      game = g;
      evolutionManager = new EvolutionManager(this, game);

      x = vx;
      y = vy;
      intent = INTENT_ATTACH;
      state = STATE_PARASITE;
      ap = 2;

      energy = STARTING_ENERGY;
      maxEnergy = STARTING_ENERGY;
      chemicals = [ 0, 0, 0 ];
      maxChemicals = [ 20, 20, 20 ];
      attachHold = 0;
      hostTimer = 0;
      hostControl = 0;

      humanSociety = 0.0;
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
          energy -= 10;
          if (state == STATE_PARASITE && energy <= 0)
            {
              game.finish('lose', 'noHost');
              return;
            }
        }

      // state: host (chemicals harvesting and energy restoration)
      if (state == STATE_HOST)
        {
          chemicals[0] += 1;
          chemicals[1] += 1;
          chemicals[2] += 1;
          chemicals[0] = Const.clamp(chemicals[0], 0, maxChemicals[0]);
          chemicals[1] = Const.clamp(chemicals[1], 0, maxChemicals[1]);
          chemicals[2] = Const.clamp(chemicals[2], 0, maxChemicals[2]);

          energy += 10;
          evolutionManager.turn();
        }

      // state: host (host lifetime timer)
      if (state == STATE_HOST)
        {
          // knowledge about human society raises automatically
          // if host memory is available
          if (host.type == 'human' && evolutionManager.getLevel('hostMemory') > 0)
            humanSociety += 0.1 * host.intellect;

          hostTimer--;
          if (hostTimer <= 0)
            {
              onHostDeath();

              log('Your host has expired. You have to find a new one.');
            }
        }

      // state: host (we might lose it with host timer earlier)
      if (state == STATE_HOST)
        {
          hostControl--;
          if (hostControl <= 0)
            {
              host.onDetach();
              onDetach();

              game.log("You've lost control of the host.");
            }
        }

      ap = 2;
    }


// ==============================   ACTIONS   =======================================


// do a player action by string id
// action energy availability is checked when the list is formed
  public function action(actionName: String)
    {
      var action = Const.getAction(actionName);

      // harden grip on the victim
      if (actionName == 'hardenGrip')
        actionHardenGrip();

      // invade host 
      else if (actionName == 'invadeHost')
        actionInvadeHost();

      // try to reinforce control over host 
      else if (actionName == 'reinforceControl')
        actionReinforceControl();

      // try to leave current host
      else if (actionName == 'leaveHost')
        actionLeaveHost();

      // access host memory
      else if (actionName == 'accessMemory')
        actionAccessMemory();

      energy -= action.energy;

      // host could've died from some of these actions
      if (state == STATE_HOST && host.health == 0)
        {
          onHostDeath();

          log('Your host has died.');
        }

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
  function actionHardenGrip()
    {
      game.log('You harden your grip on the host.');
      attachHold += 10;
    }


// action: try to invade this AI host
  function actionInvadeHost()
    {
//      game.log('You attempt to invade the host.');
//      if (Std.random(100) < )
      game.log('You are now in control of the host.');

      // save AI link
      host = attachHost;
      hostTimer = host.hostExpiryTurns;
      hostControl = HOST_CONTROL_BASE;
      entity.visible = false;
      attachHost = null;
      host.onInvade(); // notify ai
//      game.map.destroyAI(host);

      // change image
//      entity.setImage(host.entity.getImage(), host.entity.atlasRow);
//      entity.setMask(Const.FRAME_MASK_POSSESSED, host.entity.atlasRow);

      // set intent/state
      intent = INTENT_NOTHING;
      state = STATE_HOST;
    }


// action: try to reinforce control over host
  function actionReinforceControl()
    {
      game.log('You reinforce mental control over the host.');
      hostControl += 10 - Std.int(host.psyche / 2);
    }


// action: try to leave this AI host
  function actionLeaveHost()
    {
      host.onDetach();
      onDetach();

      game.log('You release the host.');
    }


// action: remove attached parasite from host
  function actionDetach()
    {
      attachHost.parasiteAttached = false;
      onDetach();

      game.log('You detach from the potential host.');
    }


// action: access host memory
  function actionAccessMemory()
    {
      // animals do not have any useful memories
      if (host.intellect < 2)
        {
          game.log('The brain of this host contains nothing useful.');
          return;
        }
     
      var params = evolutionManager.getParams('hostMemory');

      humanSociety += params.humanSociety * host.intellect;
      hostTimer -= params.hostTimer - host.psyche;
      host.health -= params.hostHealthBase;
      if (Std.random(100) < 25)
        host.health -= params.hostHealthMod;

      game.log('You probe the brain of the host and access its memory.');
    }


// move player by dx, dy
// returns true on success
  public function moveBy(dx: Int, dy: Int): Bool
    {
      // if player tries to move when attached, that detaches the parasite
      if (state == STATE_ATTACHED)
        actionDetach();

      var nx = x + dx;
      var ny = y + dy;

      if (!game.map.isWalkable(nx, ny))
        return false;

      // random: change movement direction
      if (state == STATE_HOST && Std.random(100) < 100 - hostControl)
        {
          log('The host resists your command.');
          var dir = game.map.getRandomDirection(x, y);
          if (dir == -1)
            throw 'nowhere to move!';

          nx = x + Const.dirx[dir];
          ny = y + Const.diry[dir];
        }

      x = nx;
      y = ny;
      if (state == STATE_HOST) // move invaded host entity with invisible player entity
        host.setPosition(x, y);

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


// ================================ EVENTS =========================================


// event: parasite detached from AI 
  public function onDetach()
    {
      // change intent
      intent = INTENT_ATTACH;
      state = STATE_PARASITE;

      // make player entity visible again
      entity.visible = true;

      // reset no host timer
      attachHost = null;
      host = null;
    }


// event: host expired
  public function onHostDeath()
    {
      game.map.destroyAI(host);
      game.map.createObject(x, y, 'body', host.type);
      game.map.updateVisibility();

      onDetach();
    }


// =================================================================================


// log
  public inline function log(s: String, ?col: Int = 0)
    {
      game.log(s, col);
    }


// =================================  SETTERS  ====================================
  function set_chemicals(v: Array<Int>)
    { 
      trace(v);
      //return energy = Const.clamp(v, 0, maxEnergy); 
      return v;
    }
  function set_energy(v: Int)
    { return energy = Const.clamp(v, 0, maxEnergy); }
  function set_attachHold(v: Int)
    { return attachHold = Const.clamp(v, 0, 100); }
  function set_hostControl(v: Int)
    { return hostControl = Const.clamp(v, 0, 100); }
  function set_hostTimer(v: Int)
    { return hostTimer = Const.clamp(v, 0); }
  function set_humanSociety(v: Float)
    { return humanSociety = Const.clampFloat(v, 0, 99.9); }


// =================================================================================


  // player states
  public static var STATE_PARASITE = 'parasite';
  public static var STATE_ATTACHED = 'attached';
  public static var STATE_HOST = 'host';

  // player intents
  public static var INTENT_ATTACH = 'attachHost';
  public static var INTENT_DETACH = 'detach';
  public static var INTENT_NOTHING = 'doNothing';

  // starting energy of parasite 
  public static var STARTING_ENERGY = 100;

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
//  var ap: Int; // action points cost
  var energy: Int; // energy cost
}
