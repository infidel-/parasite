// basic game area info

package game;

import ai.*;
import objects.*;
import const.WorldConst;
import const.ItemsConst;
import const.NameConst;
import entities.RegionEntity;

class AreaGame
{
  var game: Game;
  var region: RegionGame;

  public var icons: Array<RegionEntity>; // alert, event, npc, habitat icons

  public var id: Int; // area id
  public var name: String; // area name
  public var typeID: _AreaType; // area type id - city block, military base, etc
  public var tileID: Int; // tile id on tilemap
  public var isGenerated: Bool; // has this area been generated?
  public var isEntering: Bool; // is the player entering this area atm?
  public var isKnown: Bool; // has the player seen this area?
  public var info: AreaInfo; // area info link
  public var width: Int;
  public var height: Int;
  public var x: Int; // x,y in region
  public var y: Int;
  public var turns: Int; // turns spent in this area counter
  public var events: Array<scenario.Event>; // events array
  public var npc: List<scenario.NPC>; // npc list

  // habitat related
  public var parent: AreaGame; // parent area (for sub-areas, habitats)
  public var habitat: Habitat; // habitat stuff
  public var isHabitat: Bool; // is this area itself a habitat?
  public var hasHabitat: Bool; // does this area have a habitat?
  public var habitatAreaID: Int; // area id of habitat

  public var alertnessMod: Float; // changes to alertness until next reset
  // we store all changes until player leaves the current area for propagation
  public var alertness(get, set): Float; // area alertness (authorities) (0-100%)
  var _alertness: Float; // actual alertness storage

  static var _maxID: Int = 0; // area id counter

  // these are empty until the area has been generated
  // when player leaves the area, ai list is emptied, cells and objects are saved
  var _cells: Array<Array<Int>>; // cell types
  var _ai: List<AI>; // AI list
  var _objects: Map<Int, AreaObject>; // area objects list
  var _pathEngine: aPath.Engine;


  public function new(g: Game, r: RegionGame, tv: _AreaType, vx: Int, vy: Int)
    {
      game = g;
      events = [];
      icons = [ null, null, null, null ];
      region = r;
      isGenerated = false;
      isEntering = false;
      isKnown = false;
      isHabitat = false;
      hasHabitat = false;
      habitat = null;
      id = _maxID++;
      name = null;
      parent = null;
      x = vx;
      y = vy;
      width = 10;
      height = 10;
      _alertness = 0;
      alertnessMod = 0;
      habitatAreaID = 0;
      turns = 0;
      tileID = 0;
      npc = new List();

      _cells = [];
      _ai = new List();
      _objects = new Map();
      _pathEngine = null;

      setType(tv);
    }


// enter this area: generate if needed and update view
  public function enter()
    {
      game.debug('Area.enter()');
      game.scene.soundManager.setAmbient(info.ambient);
      turns = 0;

      game.area = this;
      isEntering = true;

      // generate new area
      if (!isGenerated)
        generate();

      // area already generated, show hidden objects
      else for (o in _objects)
        o.show();

      // enter habitat with active team
      if (isHabitat && game.group.team != null)
        game.group.team.onEnterHabitat();

      // find location to appear
      // at game start always appear on empty location
      var loc = null;
      if (!info.isInhabited || game.turns == 0)
        loc = findEmptyLocation();
      else
        {
          // location is inhabited, find random sewer hatch
          var tmp = [];
          for (o in _objects)
            if (o.type == 'sewer_hatch')
              tmp.push(o);

          if (tmp.length == 0)
            {
              trace('inhabited area with no sewers, weird');
              loc = findEmptyLocation();
            }
          else
            {
              var o = tmp[Std.random(tmp.length)];
              loc = { x: o.x, y: o.y };
            }
        }

      // recreate player host AI entity
      if (game.player.state == PLR_STATE_HOST)
        {
          game.playerArea.entity.visible = false;
          game.player.host.createEntity();
          game.player.host.entity.setMask(game.scene.entityAtlas
            [Const.FRAME_MASK_CONTROL][Const.ROW_PARASITE]);
          game.player.host.setPosition(loc.x, loc.y);
          _ai.add(game.player.host);
        }
      game.playerArea.moveTo(loc.x, loc.y);

      game.playerArea.ap = 2; // renew AP
      alertnessMod = 0; // clear alertness counter

/*
      // temporary debug stuff
      if (game.turns > 0 && info.isInhabited)
        {
          Const.todo('!!!remove this!!!');
          var info = ItemsConst.getInfo('paper');
          var o = new Paper(game, loc.x, loc.y);
          o.item = {
            id: 'paper',
            name: info.names[Std.random(info.names.length)],
            info: info,
            event: area.event
            };
          addObject(o);
          var o = new Paper(game, loc.x, loc.y);
          o.item = {
            id: 'paper',
            name: info.names[Std.random(info.names.length)],
            info: info,
            event: area.event
            };
          addObject(o);
        }
*/

      // goal received: grow camouflage layer
      if (info.isHighRisk && game.goals.completed(GOAL_EVOLVE_PROBE))
        game.goals.receive(GOAL_EVOLVE_CAMO);

      // goal completed: event area found
      if (events.length > 0)
        game.goals.complete(GOAL_TRAVEL_EVENT);

      // update area view info
      game.scene.area.update();

      // spawn some AI around player on entering area
      // called here because it uses player camera x,y
      if (game.turns != 0)
        {
          turnSpawnAI(); // spawn AI
          turnSpawnMoreAI(); // spawn AI related to area alertness
        }

      // update AI and objects visibility to player
      updateVisibility();

      isEntering = false;

      // show area
      game.scene.area.show();

      // mercifully spawn dog nearby if player has no host
      if (game.player.state == PLR_STATE_PARASITE && !isHabitat)
        {
          var spot = findEmptyLocationNear(game.playerArea.x,
            game.playerArea.y, 3);
          var ai = new ai.DogAI(game, spot.x, spot.y);
          ai.isCommon = true;
          addAI(ai);
        }
    }


// leave this area: hide gui, despawn, etc
  public function leave()
    {
      game.debug('Area.leave()');

      if (!isHabitat)
        {
          // count all bodies and discover them in bulk
          var totalPoints = 0;
          var totalBodies = 0;
          for (o in _objects)
            if (o.type == 'body')
              {
                var body: BodyObject = cast o;
                totalPoints += body.organPoints;
                totalBodies++;
              }

          // notify world about bodies discovered
          if (totalBodies == 1)
            game.managerRegion.onBodyDiscovered(this, totalPoints);

          else if (totalBodies > 0)
            game.managerRegion.onBodiesDiscovered(this, totalBodies,
              totalPoints);
        }

      // remove all ai
      for (ai in _ai)
        removeAI(ai);

      // remove host AI entity link (AI entity already removed above)
      if (game.player.state == PLR_STATE_HOST)
        game.player.host.entity = null;

      // hide static objects and remove dynamic ones
      // all objects in habitat are considered static
      for (o in _objects)
        if (o.isStatic || isHabitat)
          o.hide();
        else removeObject(o);

      // leave area with active team
      if (game.group.team != null)
        game.group.team.onLeaveArea();

      // remove events
      game.managerArea.onLeaveArea();

      // hide gui
      game.scene.area.hide();
    }


// generate a new area map
  function generate()
    {
      game.debug('Area.generate()');

      // clear map
      _cells = [];
      var baseTile = Const.TILE_WALKWAY;
      if (typeID == AREA_GROUND)
        baseTile = Const.TILE_GRASS;
      for (i in 0...width)
        _cells[i] = [];
      for (y in 0...height)
        for (x in 0...width)
          _cells[x][y] = baseTile;

      AreaGenerator.generate(game, this, info);

      // set path info
      _pathEngine = new aPath.Engine(this, width, height);

      isGenerated = true; // mark area as ready for entering

      game.debug('Area generated.');
    }


// add event object to area
  public function addEventObject(params: {
    name: String, // object name
    action: _PlayerAction, // object action
    onAction: Game -> Player -> String -> Void, // action handler
    }): EventObject
    {
      // generate area if it's not yet generated
      if (!isGenerated)
        generate();

      var loc = findEmptyLocation();
      game.debug('!!! event obj ' + params.name +
        ' loc: (' + loc.x + ',' + loc.y +
        ') area: (' + x + ',' + y + ')');
      var o = new EventObject(game, loc.x, loc.y, false);
      o.name = params.name;
      o.eventAction = params.action;
      o.eventAction.obj = o;
      o.eventOnAction = params.onAction;
      if (game.area != this) // hide object if it's not in the current area
        o.hide();

      addObject(o);
      return o;
    }


// add object to area
  public inline function addObject(o: AreaObject)
    {
      _objects.set(o.id, o);
    }


// get object by id
  public inline function getObject(id: Int): AreaObject
    {
      return _objects.get(id);
    }


// check if the area has any objects at (x,y)
  public function hasObjectAt(x: Int, y: Int): Bool
    {
      for (o in _objects)
        if (o.x == x && o.y == y)
          return true;

      return false;
    }


// get objects list at (x,y)
  public function getObjectsAt(x: Int, y: Int): List<AreaObject>
    {
      var tmp = new List<AreaObject>();

      for (o in _objects)
        if (o.x == x && o.y == y)
          tmp.push(o);

      return tmp;
    }


// remove object
  public inline function removeObject(o: AreaObject)
    {
      o.hide();
      _objects.remove(o.id);
    }


// find unseen empty location on map (to spawn stuff)
  public function findUnseenEmptyLocation(): { x: Int, y: Int }
    {
      // calculate visible rectangle
      var rect = getVisibleRect();

      // TODO: in case if this works slowly i can rewrite it to find all potential free
      // spots and select one of them
      var cnt = 0;
      while (true)
        {
          cnt++;
          if (cnt > 100)
            {
              trace('findUnseenEmptyLocation(): could not find empty spot (report this please)!');
              return { x: -1, y: -1 };
            }

          var x = rect.x1 + Std.random(rect.x2 - rect.x1);
          var y = rect.y1 + Std.random(rect.y2 - rect.y1);

          // must be empty ground tile
          if (!isWalkable(x, y))
            continue;

          // must not have ai
          if (getAI(x, y) != null)
            continue;

          // no LOS checks when player is entering the area
          if (!isEntering)
            {
              // must not be visible to player as a parasite
              if (game.player.state != PLR_STATE_HOST &&
                  Const.distanceSquared(game.playerArea.x, game.playerArea.y, x, y) < 6 * 6)
                continue;

              // must not be visible to player when possessing a host
              if (game.player.state == PLR_STATE_HOST &&
                  isVisible(game.playerArea.x, game.playerArea.y, x, y))
                continue;
            }

          return { x: x, y: y };
        }

      return { x: -1, y: -1 };
    }


// find empty location on map (to spawn stuff)
  public function findEmptyLocation(): { x: Int, y: Int }
    {
      var x = -1;
      var y = -1;
      var cnt = 0;
      while (true)
        {
          cnt++;
          if (cnt > 100)
            {
              trace('could not find empty spot!');
              return { x: 0, y: 0 };
            }

          x = Std.random(width);
          y = Std.random(height);
          if (!isWalkable(x, y))
            continue;

          if (getAI(x, y) != null)
            continue;

          break;
        }

      return { x: x, y: y };
    }


// generic find empty location method with parameters
  public function findLocation(params: {
      near: { x: Int, y: Int }, // near this x, y
      ?radius: Int, // radius to find in (for near)
      ?isUnseen: Bool, // location should be unseen by player
      ?canIncrease: Bool, // can increase radius in case of fail
    }, ?level: Int = 0): { x: Int, y: Int }
    {
      // all map
      if (params.near == null)
        {
          Const.todo('findLocation near == null');
          return null;
        }

      if (params.radius == null)
        params.radius = 3;
      if (params.canIncrease == null)
        params.canIncrease = true;

      var xo = params.near.x;
      var yo = params.near.y;

      // make a temp list of empty spots in square radius
      var tmp = [];
      for (dy in -params.radius...params.radius)
        for (dx in -params.radius...params.radius)
          {
            // no LOS checks when player is entering the area
            if (!isEntering)
              {
                // always check for LOS, even in parasite mode
                if (isVisible(game.playerArea.x, game.playerArea.y,
                      xo + dx, yo + dy))
                  continue;
              }

            if (isWalkable(xo + dx, yo + dy) &&
                getAI(xo + dx, yo + dy) == null &&
                !(game.playerArea.x == xo + dx && game.playerArea.y == yo + dy))
              tmp.push({ x: xo + dx, y: yo + dy });
          }

      // no empty cells found
      if (tmp.length == 0)
        {
          // can increase radius once
          if (level == 0 && params.canIncrease)
            {
              params.radius *= 2;
              return findLocation(params, 1);
            }
        }

      return tmp[Std.random(tmp.length)];
    }


// find empty location on map near xo,yo (to spawn stuff)
  public function findEmptyLocationNear(xo: Int, yo: Int, radius: Int, ?level: Int = 0): { x: Int, y: Int }
    {
      // make a temp list of empty spots in square radius 3
      var tmp = [];
      for (dy in -radius...radius)
        for (dx in -radius...radius)
          if (isWalkable(xo + dx, yo + dy) &&
              getAI(xo + dx, yo + dy) == null &&
              !(game.playerArea.x == xo + dx && game.playerArea.y == yo + dy))
            tmp.push({ x: xo + dx, y: yo + dy });

      // no empty cells found
      if (tmp.length == 0)
        {
          // can increase radius once
          if (level == 0)
            return findEmptyLocationNear(xo, yo, radius * 2, 1);
        }

      return tmp[Std.random(tmp.length)];
    }


// change area type
  public function setType(t: _AreaType)
    {
      typeID = t;
      info = WorldConst.getAreaInfo(typeID);

      width = info.width - 10 + 10 * Std.random(2);
      height = info.height - 10 + 10 * Std.random(2);

      if (typeID == AREA_GROUND)
        tileID = Const.TILE_REGION_GROUND;
#if !free
      else if (typeID == AREA_CITY_LOW)
        {
          tileID = Const.OFFSET_CITY;
          tileID += x % 4;
          tileID += (y % 4) * 16;
        }
      else if (typeID == AREA_CITY_MEDIUM)
        {
          tileID = Const.OFFSET_CITY + 4;
          tileID += x % 4;
          tileID += (y % 4) * 16;
        }
      else if (typeID == AREA_CITY_HIGH)
        {
          tileID = Const.OFFSET_CITY + 8;
          tileID += x % 4;
          tileID += (y % 4) * 16;
        }
#else
      else if (typeID == AREA_CITY_LOW)
        tileID = Const.TILE_CITY_LOW;
      else if (typeID == AREA_CITY_MEDIUM)
        tileID = Const.TILE_CITY_MEDIUM;
      else if (typeID == AREA_CITY_HIGH)
        tileID = Const.TILE_CITY_HIGH;
#end
      else if (typeID == AREA_MILITARY_BASE)
        tileID = Const.TILE_MILITARY_BASE1 + Std.random(2);
      else if (typeID == AREA_FACILITY)
        tileID = Const.TILE_FACILITY1 +
          Std.random(Const.TILE_MILITARY_BASE1 - Const.TILE_FACILITY1);

      // set name
      name = info.name;
      if (typeID == AREA_MILITARY_BASE)
        name = NameConst.generate('%baseA1% %baseB1%');
      else if (typeID == AREA_FACILITY)
        name = NameConst.generate('%tree1% %geo1% %lab1%');
    }


// set alertness without counting changes
// used in alertness propagation
  public inline function setAlertness(v: Float)
    {
      _alertness = Const.clampFloat(v, 0, 100.0);
    }


// get cells array
  public function getCells()
    { return _cells; }


// get string cell type of this cell
  public function getCellTypeString(x: Int, y: Int): String
    {
      if (x < 0 || y < 0 || x >= width || y >= height)
        return null;
      return Const.TILE_TYPE[_cells[x][y]];
    }


// get cell type of this cell
  public function getCellType(x: Int, y: Int): Int
    {
      if (x < 0 || y < 0 || x >= width || y >= height)
        return -1;
      return _cells[x][y];
    }


// does this cell has ai?
  public function hasAI(x: Int, y: Int): Bool
    {
      for (ai in _ai)
        if (ai.x == x && ai.y == y)
          return true;

      return false;
    }


// get ai on this cell
  public function getAI(x: Int, y: Int): AI
    {
      for (ai in _ai)
        if (ai.x == x && ai.y == y)
          return ai;

      return null;
    }


// set cell type
  public inline function setCellType(x: Int, y: Int, index: Int)
    {
      if (x >= 0 && y >= 0 && x < width && y < height)
        _cells[x][y] = index;
    }


// check if tile is walkable
  public function isWalkable(x: Int, y: Int): Bool
    {
      if (x < 0 || y < 0 || x >= width || y >= height)
        return false;

//      trace(x + ' ' + y + ' ' + _isWalkable[x][y]);
      return Const.TILE_WALKABLE[_cells[x][y]];
    }


// check if x1, y1 sees x2, y2
// bresenham copied from wikipedia with one slight modification
  public function isVisible(x1: Int, y1: Int, x2: Int, y2: Int, ?doTrace: Bool)
    {
      var ox2 = x2;
      var oy2 = y2;
      var steep: Bool = (Math.abs(y2 - y1) > Math.abs(x2 - x1));
      var tmp: Int;
      if (steep)
        {
          // swap x1 and y1
          tmp = x1;
          x1 = y1;
          y1 = tmp;

          // swap x2 and y2
          tmp = x2;
          x2 = y2;
          y2 = tmp;
        }

      // make sure x1 < x2
      if (x1 > x2)
        {
          // swap x1 and x2
          tmp = x1;
          x1 = x2;
          x2 = tmp;

          // swap y1 and y2
          tmp = y1;
          y1 = y2;
          y2 = tmp;
        }

      var dx: Int = x2 - x1;
      var dy: Int = Math.floor(Math.abs(y2 - y1));
      var error: Int = Math.floor(dx / 2);
      var yy: Int = y1;
      var ystep: Int = (y1 < y2 ? 1 : -1);

      for (xx in x1...x2)
        {
          // check if this x,y is walkable
          var ok = true;
          if (steep)
            {
//              if (doTrace)
//                trace(yy + ',' + xx);
              ok = isWalkable(yy, xx);

              // slight modification - even if endpoint is not walkable, it's still visible
              if (ox2 == yy && oy2 == xx)
                ok = true;
            }
          else
            {
//              if (doTrace)
//                trace(xx + ',' + yy);
              ok = isWalkable(xx, yy);

              // slight modification - even if endpoint is not walkable, it's still visible
              if (ox2 == xx && oy2 == yy)
                ok = true;
            }

          if (!ok)
            return false;

          error -= dy;
          if (error < 0)
            {
              yy = yy + ystep;
              error = error + dx;
            }
        }

      return true;
    }


// add AI to map
  public function addAI(ai: AI)
    {
      _ai.add(ai);
      ai.createEntity();
    }


// remove AI
  public function removeAI(ai: AI)
    {
//      game.debug('AI remove ' + ai.id);
      // event: despawn live AI
      if (ai.state != AI_STATE_DEAD && ai != game.player.host)
        ai.onRemove();

      if (ai.npc != null)
        ai.npc.ai = null;
      ai.entity.remove();
      ai.entity = null;
      _ai.remove(ai);
    }


// TURN: area time passage - ai actions, object events
  public function turn()
    {
      // turns spent in this area
      turns++;

      // AI logic
      for (ai in _ai)
        {
          ai.turn();

          if (game.isFinished)
            return;
        }

      // object logic
      for (o in _objects)
        o.turn();

      // call turn for area view
      game.scene.area.turn();

      turnSpawnAI(); // spawn AI
      turnSpawnMoreAI(); // spawn AI related to area alertness
      turnSpawnNPC(); // spawn NPC AI
      turnSpawnClues(); // spawn clues
      turnSpawnTeam(); // spawn team agents
      turnAlertness(); // decrease alertness
    }


// spawn group team members
  function turnSpawnTeam()
    {
      var team = game.group.team;
      if (team == null || isHabitat)
        return;

      // limit spawns by turns spent in this area
      if (turns < team.distance)
        return;

      // introduce some randomness
      if (Std.random(100) > 20)
        return;

      // count number of spawned team members
      var numSpawned = 0;
      for (ai in _ai)
        if (ai.isTeamMember && !ai.parasiteAttached)
          numSpawned++;

      var numFree = team.size - numSpawned;
      if (numFree <= 0)
        return;

      // spawn a team member
      var ai = spawnUnseenAI('team', false);
      if (ai == null)
        return;
      ai.isTeamMember = true;

      game.debug('Team member spawned');
    }


// spawn some clues
  function turnSpawnClues()
    {
      if (!game.player.vars.timelineEnabled || events.length == 0)
        return;

      // NOTE: hmm, it appears that if player stumbles into event location by
      // chance, the clues will spawn anyway. it wasn't intentional but
      // but i'll leave it like that.

      // get the event for which to spawn clues for
      var e = null;
      for (ev in events)
        {
          // all event notes and npcs names/jobs known
          if (ev.notesKnown() && ev.npcNamesOrJobsKnown())
            continue;

          e = ev;

          // i could put events into a temp array but not much need to
          if (Std.random(2) == 0)
            break;
        }
      if (e == null)
        return;

      // get number of clues already spawned
      var cnt = 0;
      for (o in _objects)
        if (o.item != null && o.item.info.type == 'readable')
          cnt++;

      var maxSpawn = 5 - cnt;

      var info = ItemsConst.getInfo(Std.random(100) < 80 ? 'paper' : 'book');
      for (i in 0...maxSpawn)
        {
          var loc = findUnseenEmptyLocation();
          if (loc.x < 0)
            {
              trace('Area.turnSpawnClues(): no free spot for another ' +
                info.id + ', please report');
              return;
            }

          var o: AreaObject = Type.createInstance(info.areaObjectClass,
            [ game, loc.x, loc.y ]);
          o.name = info.names[Std.random(info.names.length)];
          o.item = {
            id: info.id,
            name: o.name,
            info: info,
            event: e
            };
          addObject(o);
        }
    }


// decrease area alertness
  function turnAlertness()
    {
      // count number of alerted AI
      var cnt = 0;
      for (ai in _ai)
        if (ai.state == AI_STATE_ALERT)
          cnt++;

      if (cnt > 0)
        return;

      alertness -= 0.1;
    }


// spawn NPC AI each turn
  function turnSpawnNPC()
    {
      // no npcs here
      if (npc.length == 0)
        return;

      // npc spawn not enabled yet
      if (!game.player.vars.npcEnabled)
        return;

      // count total npcs with photo known and alive
      var total = 0;
      for (n in npc)
        if (n.jobKnown && !n.isDead)
          total++;

      // get number of npcs alive (excluding player one)
      var cnt = 0;
      for (ai in _ai)
        if (ai.npc != null && !ai.parasiteAttached)
          cnt++;

      if (cnt > 2)
        return;

      var maxSpawn = total - cnt;
      if (maxSpawn > 3)
        maxSpawn = 3;

      var i = 0;
      for (n in npc)
        // alive, unspawned and job/photo known
        if (n.jobKnown && !n.isDead && n.ai == null)
          {
            var ai = spawnUnseenAI(n.type, true);
            if (ai == null)
              break;
            game.debug('spawn npc');
            n.ai = ai;
            ai.event = n.event;
            ai.job = n.job;
            ai.npc = n;
            ai.name.real = n.name;
            ai.name.realCapped = n.name;
            ai.isMale = n.isMale;
            ai.isNameKnown = true;
            ai.isJobKnown = true;
            ai.entity.setNPC();

            // spawn up to maxSpawn npcs
            i++;
            if (i >= maxSpawn)
              break;
          }
    }


// spawn new AI, called each turn
  function turnSpawnAI()
    {
      if (info.commonAI == 0)
        return;

      // get number of common AI
      var cnt = 0;
      for (ai in _ai)
        if (ai.isCommon)
          cnt++;
      // do not count player
      if (game.player.state == PLR_STATE_HOST)
        cnt--;

      // calc max possible number of AI
      var maxAI =
        Std.int(info.commonAI * game.scene.area.emptyScreenCells /
          WorldConst.AREA_AI_CELLS);
/*
      trace('info:' + info.commonAI +
        ' empty:' + game.scene.area.emptyScreenCells +
        ' res:' + maxAI + ' cnt:' + cnt);
*/

      // there are enough AI already
      if (cnt > maxAI)
        return;

      // limit number of spawns per turn
      var maxSpawn = maxAI - cnt;
      if (maxSpawn > 10)
        maxSpawn = 10;

      for (i in 0...maxSpawn)
        {
          // get random ai class id based on probability
          var rnd = Std.random(100);
          var min = 0;
          var type = null;
          for (key in info.ai.keys())
            {
              if (rnd < min + info.ai[key])
                {
                  type = key;
                  break;
                }

              min += info.ai[key];
            }

          spawnUnseenAI(type, true); // spawns AI at spot unseen by player
        }
    }


// spawn some more AI related to area alertness
  function turnSpawnMoreAI()
    {
      if (info.uncommonAI == 0)
        return;

      // get number of uncommon AI (spawned by alertness logic)
      var cnt = 0;
      for (ai in _ai)
        if (!ai.isCommon)
          cnt++;

      // calc max possible number of AI
      var maxAI =
        Std.int(info.uncommonAI * game.scene.area.emptyScreenCells /
          WorldConst.AREA_AI_CELLS);
/*
      trace('info:' + info.uncommonAI +
        ' empty:' + game.scene.area.emptyScreenCells +
        ' res:' + maxAI + ' cnt:' + cnt);
*/

      // calculate the actual number to spawn according to the area alertness
      var uncommonAI = Std.int(maxAI * alertness / 100.0);

      // there are enough uncommon AI already
      if (cnt >= uncommonAI)
        return;

      game.info('Uncommon AI ' + cnt + '/' + uncommonAI +
        ' (alertness: ' + Const.round(alertness) + '%, max: ' +
        info.uncommonAI + ')');

      // limit number of spawns per turn
      var maxSpawn = uncommonAI - cnt;
      if (maxSpawn > 10)
        maxSpawn = 10;

      // more spawns here based on area alertness
      // TODO: i'll probably change this later to reflect different area types
      // and also add stages etc
      // for now let's keep it simple
      for (i in 0...maxSpawn)
        spawnUnseenAI('police', false);
    }


// spawn unseen AI with this type somewhere in screen area
  function spawnUnseenAI(type: String, isCommon: Bool): AI
    {
      var loc = findUnseenEmptyLocation();
      if (loc.x < 0)
        {
          trace('Area.spawnUnseenAI(): no free spot for another ' +
            type + ', please report');
          return null;
        }

      // spot is empty and invisible to player, spawn ai
      var ai: AI = null;
      if (type == 'dog')
        ai = new DogAI(game, loc.x, loc.y);
      else if (type == 'civilian')
        ai = new CivilianAI(game, loc.x, loc.y);
      else if (type == 'police')
        ai = new PoliceAI(game, loc.x, loc.y);
      else if (type == 'soldier')
        ai = new SoldierAI(game, loc.x, loc.y);
      else if (type == 'security')
        ai = new SecurityAI(game, loc.x, loc.y);
      else if (type == 'agent')
        ai = new AgentAI(game, loc.x, loc.y);
      else if (type == 'team')
        ai = new TeamMemberAI(game, loc.x, loc.y);
      else throw 'spawnUnseenAI(): AI type [' + type + '] unknown';

      ai.isCommon = isCommon;
      addAI(ai);

      return ai;
    }


// get visible rectangle for this area
  public function getVisibleRect(): { x1: Int, y1: Int, x2: Int, y2: Int }
    {
      var rect = {
        x1: game.scene.cameraTileX1 - 1,
        y1: game.scene.cameraTileY1 - 1,
        x2: game.scene.cameraTileX2 + 2,
        y2: game.scene.cameraTileY2 + 2
      };

      if (rect.x1 < 0)
        rect.x1 = 0;
      if (rect.y1 < 0)
        rect.y1 = 0;
      if (rect.x2 > width)
        rect.x2 = width;
      if (rect.y2 > height)
        rect.y2 = height;

      return rect;
    }


// checks if this x,y is on screen
  public inline function inVisibleRect(x: Int, y: Int): Bool
    {
      return (x >= game.scene.cameraTileX1 &&
        y >= game.scene.cameraTileY1 &&
        x < game.scene.cameraTileX2 &&
        y < game.scene.cameraTileY2);
    }


// update AI visibility
  public inline function updateVisibility()
    {
      if (game.player.state == PLR_STATE_HOST)
        updateVisibilityHost();
      else updateVisibilityParasite();

      game.scene.area.updateVisibility();
    }


// update AI, objects visibility
// host version
  function updateVisibilityHost()
    {
      for (ai in _ai)
        {
          var v = isVisible(game.playerArea.x, game.playerArea.y, ai.x, ai.y);
          // noticed by player for the first time
          if (!ai.wasNoticed && v && inVisibleRect(ai.x, ai.y))
            {
              ai.wasNoticed = true;
              ai.onNotice();
            }

          ai.entity.visible = (game.player.vars.losEnabled ? v : true);
        }

      for (obj in _objects)
        obj.entity.visible =
          (game.player.vars.losEnabled ?
            isVisible(game.playerArea.x, game.playerArea.y, obj.x, obj.y) : true);
    }


// update visible area (also AI, objects visibility)
// parasite version
// parasite only sees one tile around him but "feels" AIs in a larger radius
  function updateVisibilityParasite()
    {
      for (ai in _ai)
        if (game.player.vars.losEnabled)
          ai.entity.visible =
            (Const.distanceSquared(game.playerArea.x, game.playerArea.y, ai.x, ai.y) < 6 * 6);
        else ai.entity.visible = true;

      for (obj in _objects)
        if (game.player.vars.losEnabled)
          obj.entity.visible =
            (Const.distanceSquared(game.playerArea.x, game.playerArea.y, obj.x, obj.y) < 6 * 6);
        else obj.entity.visible = true;
    }


// get random direction to a near empty space
// returns index of Const.dirx[], Const.diry[]
  public function getRandomDirection(x: Int, y: Int): Int
    {
      // form a temp list of walkable dirs
      var tmp = [];
      for (i in 0...Const.dirx.length)
        {
          var nx = x + Const.dirx[i];
          var ny = y + Const.diry[i];
          var ok =
            (isWalkable(nx, ny) &&
             !hasAI(nx, ny) &&
             !(game.playerArea.x == nx && game.playerArea.y == ny));
          if (ok)
            tmp.push(i);
        }

      // nowhere to go, return
      if (tmp.length == 0)
        {
          trace('ai at (' + x + ',' + y + '): no dirs');
          return -1;
        }

      return tmp[Std.random(tmp.length)];
    }


// get all AIs in radius from that x,y
// los - must have los to that location
  public function getAIinRadius(x: Int, y: Int, dist: Int, los: Bool): List<AI>
    {
      var tmp = new List<AI>();

      for (ai in _ai)
        if (Const.distanceSquared(x, y, ai.x, ai.y) <= dist * dist &&
            (!los || isVisible(ai.x, ai.y, x, y)))
          tmp.add(ai);

      return tmp;
    }


// get all AI
  public inline function getAllAI(): List<AI>
    { return _ai; }

// get all objects in radius from that x,y
// los - must have los to that location
  public function getObjectsInRadius(x: Int, y: Int, dist: Int, los: Bool): List<AreaObject>
    {
      var tmp = new List<AreaObject>();

      for (o in _objects)
        if (Const.distanceSquared(x, y, o.x, o.y) <= dist * dist &&
            (!los || isVisible(o.x, o.y, x, y)))
          tmp.add(o);

      return tmp;
    }


// get objects iterator
  public function getObjects(): Iterator<AreaObject>
    {
      return _objects.iterator();
    }


// get path from x1, y1 -> x2, y2
  public function getPath(x1: Int, y1: Int, x2: Int, y2: Int): Array<aPath.Node>
    {
      if (!isWalkable(x1, y1) || !isWalkable(x2, y2) || (x1 == x2 && y1 == y2))
        return null;

      try {
      var p = _pathEngine.getPath(x1, y1, x2, y2);
//      trace('path generation time: ' + Std.int((Sys.time() - t) * 1000.0) + ' ms');
      return p;
      }
      catch (e: Dynamic)
        {
          trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
        }
      return null;
    }


// does this area have any AI?
  public inline function hasAnyAI(): Bool
    {
      return (game.player.state == PLR_STATE_HOST ? _ai.length > 1 : _ai.length > 0);
    }

// DEBUG: show all objects
  public inline function debugShowObjects()
    {
      for (o in _objects)
        trace(o);
    }


  public function toString(): String
    {
      return '(' + x + ',' + y + '): ' + typeID + ' alertness:' + alertness;
    }


// ========================== SETTERS ====================================


  function get_alertness()
    { return _alertness; }

  function set_alertness(v: Float)
    {
      var mod = v - _alertness;
      // save alertness changes for later use
      alertnessMod += v - _alertness;
      _alertness = Const.clampFloat(v, 0, 100.0);

      if (game.isInited)
        {
          if (mod >= 1)
            game.infoChange('Area alertness', mod, _alertness);

          // chance of bleeding into group priority
          if (mod >= 1 && v > 25 && Std.random(100) < v)
            game.group.raisePriority(1);
        }

      return _alertness;
    }
}
