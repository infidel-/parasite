// NPC AI game state

import entities.AIEntity;

class AI
{
  var game: Game; // game state link

  public var entity: AIEntity; // gui entity
  public var type: String; // object type
  public var name: String; // AI name (can be unique and capitalized)

  public var x: Int; // grid x,y
  public var y: Int;
  var direction: Int; // direction of movement

  public var state: String; // AI state
  public var alertness: Int; // 0-100, how alert is AI to the parasite
  public var alertTimer: Int; // when alerted, this will go down until AI calms down

  // stats
  public var strength: Int; // physical strength (1-10)
  public var hostExpiryTurns: Int; // amount of turns until this host expires

  // state vars
  public var parasiteAttached: Bool; // is parasite currently attached to this AI

  public function new(g: Game, vx: Int, vy: Int)
    {
      game = g;
      type = 'undefined';

      x = vx;
      y = vy;

      state = STATE_IDLE;
      alertness = 0;
      alertTimer = 0;
      direction = 0;
      parasiteAttached = false;
      strength = 1;
      hostExpiryTurns = 10;
    }


// create entity for this AI
  public function createEntity()
    {
      var atlasRow: Dynamic = Reflect.field(Const, 'ROW_' + type.toUpperCase());
      if (atlasRow == null)
        {
          trace('No such entity type: ' + type);
          return;
        }
      entity = new AIEntity(this, game, x, y, atlasRow);
      game.scene.add(entity);
    }


// set position
  public function setPosition(vx: Int, vy: Int)
    {
      x = vx;
      y = vy;
      entity.setPosition(x, y);
    }


// AI logic: roam around (default)
  public function logicRoam()
    {
      if (Math.random() < 0.2)
        changeRandomDirection();

      var nx = x + Const.dirx[direction];
      var ny = y + Const.diry[direction];
      var ok = 
        (game.map.isWalkable(nx, ny) && 
         !game.map.hasAI(nx, ny) && 
         !(game.player.x == nx && game.player.y == ny));
      if (!ok)
        {
          changeRandomDirection();
          return;
        }
      else setPosition(nx, ny);
    }


// AI logic: run away from this x,y
  function logicRunAwayFrom(xx: Int, yy: Int)
    {
      // form a temp list of dirs that have empty tiles and are as far away
      // from threat as possible
      var tmp = [];
      for (i in 0...Const.dirx.length)
        {
          var nx = x + Const.dirx[i];
          var ny = y + Const.diry[i];
          var ok = (
            game.map.isWalkable(nx, ny) && !game.map.hasAI(nx, ny) && 
              (Math.abs(nx - game.player.x) >= Math.abs(x - game.player.x) &&
               Math.abs(ny - game.player.y) >= Math.abs(y - game.player.y))
            );
          if (ok)
            tmp.push(i);
        }

      // nowhere to run
      if (tmp.length == 0)
        {
          Const.todo('is in panic and has nowhere to run!');
          return;
        }

      direction = tmp[Std.random(tmp.length)];
//      trace('tmp: ' + tmp + ' ai at (' + x + ',' + y + '): dir: ' + direction +
//        ' n:' + (x + Const.dirx[direction]) + ',' + (y + Const.diry[direction]));

//      var distSqr = Const.getDistSquared(x, y, xx, yy);
      var nx = x + Const.dirx[direction];
      var ny = y + Const.diry[direction];
      setPosition(nx, ny);
    }


// AI logic: try to tear parasite away
  function logicTearParasiteAway()
    {
      log('tries to tear you away!');

      game.player.attachHold -= strength;
      if (game.player.attachHold > 0)
        return;

      parasiteAttached = false;
      log('manages to tear you away.'); 
      game.player.onDetach(); // notify player
    }


// internal: change direction at random to the empty space
  function changeRandomDirection()
    {
      // form a temp list of walkable dirs
      var tmp = [];
      for (i in 0...Const.dirx.length)
        {
          var nx = x + Const.dirx[i];
          var ny = y + Const.diry[i];
          var ok = 
            (game.map.isWalkable(nx, ny) && 
             !game.map.hasAI(nx, ny) && 
             !(game.player.x == nx && game.player.y == ny));
          if (ok)
            tmp.push(i);
        }

      // nowhere to go, return
      if (tmp.length == 0)
        {
          trace('ai at (' + x + ',' + y + '): no dirs');
          return;
        }

      direction = tmp[Std.random(tmp.length)];
/*      
      if (x < 20 && y < 20) 
        trace(tmp + ' ai at (' + x + ',' + y + '): dir' + direction +
          ' n:' + (x + Const.dirx[direction]) + ',' + (y + Const.diry[direction]));
*/          
    }


// does this AI sees this position?
  function seesPosition(xx: Int, yy: Int): Bool
    {
      // too far away
      var distSqr = Const.getDistSquared(x, y, xx, yy);
      if (distSqr > Const.AI_VIEW_DISTANCE * Const.AI_VIEW_DISTANCE)
        return false;

      // check for visibility
      if (!game.map.isVisible(x, y, xx, yy))
        return false;

      return true;
    }


// state: default idle state handling
  function stateIdle()
    {
      // alertness update
      if (seesPosition(game.player.x, game.player.y))
        {
          var distance = Const.getDist(x, y, game.player.x, game.player.y);
          alertness += 3 * (Const.AI_VIEW_DISTANCE + 1 - distance);
        }
      else alertness -= 5;

      // AI has become alerted
      if (alertness >= 100)
        {
          setState(STATE_ALERT);
          return;
        }

      // stand and wonder what happened until alertness go down
      if (alertness > 0)
        return;

      // TODO: i could make hooks here, leaving the alert logic intact

      // roam by default
      logicRoam();
    }


// state: default alert state handling
  function stateAlert()
    {
      // alerted timer update
      if (seesPosition(game.player.x, game.player.y))
        alertTimer = Const.AI_ALERTED_TIMER;
      else alertTimer--;
  
      // AI calms down
      if (alertTimer == 0)
        {
          state = STATE_IDLE;
          alertness = 90;
          return;
        }

      // TODO: i could make hooks here, leaving the alert logic intact

      // parasite attached - try to tear it away
      if (parasiteAttached)
        logicTearParasiteAway();
        
      // try to run away
      else logicRunAwayFrom(game.player.x, game.player.y);
    }


// call AI logic
  public function ai()
    {
      if (state == STATE_IDLE)
        stateIdle();

      // AI alerted - try to run away or attack
      else if (state == STATE_ALERT)
        stateAlert();

      // clamp and change entity icons
      updateEntity();
    }


// set AI state (plus all vars for this state)
  public function setState(vstate: String)
    {
      state = vstate;
      if (state == STATE_ALERT)
        alertTimer = Const.AI_ALERTED_TIMER;
    }


// event: parasite attached to this host
  public function onAttach()
    {
      // set AI state
      parasiteAttached = true;
      setState(AI.STATE_ALERT);
    }


// post alert changes, clamp and change icon
  function updateEntity()
    {
      // clamp stuff
      if (alertness < 0)
        alertness = 0;

      if (alertness > 100)
        alertness = 100;

      var alertFrame = Const.FRAME_EMPTY;
      if (state == STATE_ALERT)
        alertFrame = Const.FRAME_ALERTED;
      else if (alertness > 75)
        alertFrame = Const.FRAME_ALERT3;
      else if (alertness > 50)
        alertFrame = Const.FRAME_ALERT2;
      else if (alertness > 0)
        alertFrame = Const.FRAME_ALERT1;

      entity.setAlert(alertFrame);
    }


// log
  public inline function log(s: String)
    {
      game.log(name + ' ' + s);
    }


  // AI states
  public static var STATE_IDLE = 'idle';
  public static var STATE_ALERT = 'alert';
}
