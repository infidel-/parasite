// game area

package game;

import ai.*;
import objects.*;
import const.WorldConst;
import const.ItemsConst;
import const.NameConst;

class AreaGame extends _SaveObject
{
  static var _ignoredFields = [
    'region', 'events', 'npc', 'parent',
    'info', 'clueSpawnPoints',
  ];
  var game: Game;
  var region: RegionGame;
  public var regionID: Int;

  public var id: Int; // area id
  public var name: String; // area name
  public var typeID: _AreaType; // area type id - city block, military base, etc
  public var tileID: Int; // tile id on tilemap
  public var isGenerated: Bool; // has this area been generated?
  public var isEntering: Bool; // is the player entering this area atm?
  public var isKnown: Bool; // has the player seen this area?
  public var highCrime: Bool; // low density area can become high crime
  public var info: AreaInfo; // area info link
  public var width: Int;
  public var height: Int;
  public var x: Int; // x,y in region
  public var y: Int;
  public var turns: Int; // turns spent in this area counter
  public var events: Array<scenario.Event>; // events array
  public var npc: List<scenario.NPC>; // npc list

  // habitat related
  public var parentID: Int;
  public var parent(get, null): AreaGame; // parent area (for sub-areas, habitats)
  public var habitat: Habitat; // habitat stuff
  public var isHabitat: Bool; // is this area itself a habitat?
  public var hasHabitat: Bool; // does this area have a habitat child?
  public var habitatAreaID: Int; // area id of habitat

  public var alertnessMod: Float; // changes to alertness until next reset
  // we store all changes until player leaves the current area for propagation
  public var alertness(get, set): Float; // area alertness (authorities) (0-100%)
  var _alertness: Float; // actual alertness storage

  public static var _maxID: Int = 0; // area id counter

  // these are empty until the area has been generated
  // when player leaves the area, ai list is emptied, cells and objects are saved
  var _cells: Array<Array<Int>>; // cell types
  var _ai: List<AI>; // AI list
  var _objects: Map<Int, AreaObject>; // area objects list
  var _pathEngine: aPath.Engine;
  public var clueSpawnPoints: Array<{ x: Int, y: Int }>;
  public var guardSpawnPoints: Array<{ x: Int, y: Int }>;
  public var importantGuardSpawnPoints: Array<{ x: Int, y: Int }>;
  public var generatorInfo: _GeneratorInfo;


  public function new(g: Game, r: RegionGame, tv: _AreaType, vx: Int, vy: Int)
    {
      game = g;
      region = r;
      regionID = r.id;
      id = _maxID++;
      x = vx;
      y = vy;
      init();
      typeID = tv; // reset to correct on create
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      typeID = AREA_GROUND;
      events = [];
      isGenerated = false;
      isEntering = false;
      isKnown = false;
      isHabitat = false;
      hasHabitat = false;
      highCrime = false;
      habitat = null;
      name = null;
      parentID = -1;
      width = -1;
      height = -1;
      _alertness = 0;
      alertnessMod = 0;
      habitatAreaID = 0;
      turns = 0;
      tileID = 0;
      npc = new List();
      _cells = [];
      clueSpawnPoints = [];
      guardSpawnPoints = [];
      importantGuardSpawnPoints = [];
      _ai = new List();
      _objects = new Map();
      _pathEngine = null;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
      if (!onLoad)
        updateType();
      else
        {
          info = WorldConst.getAreaInfo(typeID);
        }
      if (onLoad && isGenerated)
        _pathEngine = new aPath.Engine(this, width, height);
    }

// called after main load
  public function loadPost()
    {
      region = game.world.get(regionID);
      if (id > AreaGame._maxID)
        AreaGame._maxID = id;
      for (ai in _ai)
        {
          if (ai.id > AIData._maxID)
            AIData._maxID = ai.id;
          ai.loadPost();
        }
      for (o in _objects)
        if (o.id > AreaObject._maxID)
          AreaObject._maxID = o.id;
    }

// enter this area: generate if needed and update view
  public function enter()
    {
//      game.debug('Area.enter()');
      game.scene.sounds.setAmbient(info.ambient);
      turns = 0;
      game.area = this;
      isEntering = true;

      // generate new area
      if (!isGenerated)
        generate();

      // area already generated
      else
        {
          // show all ai
          for (ai in _ai)
            ai.show();

          // show all objects
          for (o in _objects)
            o.show();
        }

      // reinit spawn points
      initSpawnPoints();

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
          // location is inhabited, find random exit object
          var tmp = [];
          for (o in _objects)
            if (o.type == info.exit)
              tmp.push(o);

          if (tmp.length == 0)
            {
              trace('inhabited area with no ' + info.exit + ' objects, weird');
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
          game.player.host.createEntity();
          game.player.host.entity.setMask(
            Const.FRAME_MASK_CONTROL);
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
          turnSpawnCommonAI(); // spawn AI
          turnSpawnMoreAI(); // spawn AI related to area alertness
          spawnGuards(); // spawn guards and such
        }

      // update AI and objects visibility to player
      updateVisibility();
      game.scene.area.onEnter();
      game.scene.sounds.onEnterArea();
      // timeline goals hooks
      game.goals.onEnter();

      isEntering = false;

      // mercifully spawn dog nearby if player has no host
      // not on hard survival difficulty
      if (game.player.state == PLR_STATE_PARASITE &&
          game.player.difficulty != HARD &&
          !isHabitat)
        {
          var spot = findEmptyLocationNear(game.playerArea.x,
            game.playerArea.y, 3);
          var ai = new ai.DogAI(game, spot.x, spot.y);
          ai.isCommon = true;
          addAI(ai);
        }

      // notify cult about area entry
      game.cults[0].onEnterArea();
    }

// partially enter area on load
  public function currentAreaLoadPost()
    {
      game.scene.sounds.setAmbient(info.ambient);
      for (o in _objects)
        o.show();

      // reinit spawn points
      initSpawnPoints();

      // update area view info
      game.scene.area.update();

      // update AI and objects visibility to player
      updateVisibility();

      game.scene.area.draw();
    }

// init spawn points list after generation or loading
// necessary for more optimal clue/guard spawns in facilities
// NOTE: used in scenario spaceship generation part
  public function initSpawnPoints()
    {
      if (info.id != AREA_FACILITY)
        return;
      clueSpawnPoints = [];
      guardSpawnPoints = [];
      importantGuardSpawnPoints = [];
      for (y in 0...height)
        for (x in 0...width)
          {
            // tables only
            if (_cells[x][y] < Const.TILE_LABS_TABLE_3X3_7 || 
                _cells[x][y] > Const.TILE_LABS_TABLE2_1X1)
              continue;
            // check if there's an object there
            if (hasObjectAt(x, y))
              continue;
            clueSpawnPoints.push({ x: x, y: y });
          }
//      trace('clueSpawnPoints len:' + clueSpawnPoints.length);

      // check all doors and get guard points outside of the doors to the side
      for (o in _objects)
        {
          if (o.type == 'door')
            {
              for (i in 0...Const.dirdiagx.length)
                {
                  var x = o.x + Const.dirdiagx[i];
                  var y = o.y + Const.dirdiagy[i];
                  if (!isWalkable(x, y))
                    continue;
                  var addImp = false, addNormal = false;
                  // outside hangar door
                  if (o.imageCol == Const.FRAME_DOOR_METAL &&
                      _cells[x][y] != Const.TILE_FLOOR_CONCRETE)
                    addImp = true;
                  // outside of the building doors
                  else if (o.imageCol == Const.FRAME_DOOR_DOUBLE &&
                      _cells[x][y] != Const.TILE_FLOOR_LINO)
                    addImp = true;
                  else if (o.imageCol == Const.FRAME_DOOR_GLASS &&
                      _cells[x][y] != Const.TILE_FLOOR_LINO)
                    addImp = true;
                  // outside of the inner doors
                  else if (o.imageCol == Const.FRAME_DOOR_CABINET &&
                      _cells[x][y] == Const.TILE_FLOOR_LINO)
                    addNormal = true;
                  var pt = { x: x, y: y };
                  if (addImp)
                    {
                      for (tmp in importantGuardSpawnPoints)
                        if (tmp.x == pt.x && tmp.y == pt.y)
                          {
                            addImp = false;
                            break;
                          }
                      if (addImp)
                        importantGuardSpawnPoints.push(pt);
                    }
                  else if (addNormal)
                    {
                      for (tmp in guardSpawnPoints)
                        if (tmp.x == pt.x && tmp.y == pt.y)
                          {
                            addNormal = false;
                            break;
                          }
                      if (addNormal)
                        guardSpawnPoints.push(pt);
                    }
                }
            }
        }
//      trace(importantGuardSpawnPoints);
//      trace(guardSpawnPoints);
    }

// leave this area: hide gui, despawn, etc
  public function leave()
    {
//      game.debug('Area.leave()');
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
        {
          if (ai.state == AI_STATE_PRESERVED)
            ai.hide();
          else removeAI(ai);
        }

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

      // notify cult about leaving area
      game.cults[0].onLeaveArea();
    }

// generate a new area map
  public function generate()
    {
      if (isGenerated)
        return;
//      game.debug('Area.generate()');

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

      // measure generation time
      var t = Sys.time();
      game.areaGenerator.generate(this, info);
      var msec = (Sys.time() - t) * 1000.0;
      trace('Area generated in ' + Std.int(msec) + ' ms');

      // set path info
      _pathEngine = new aPath.Engine(this, width, height);

      isGenerated = true; // mark area as ready for entering
      // if the player is in different area currently, hide objects
      // used when area is generated remotely (event object spawn, etc)
      if (!isEntering)
        for (o in _objects)
          if (o.isStatic || isHabitat)
            o.hide();
          else removeObject(o);

//      game.debug('Area generated.');
    }

// get largest rect from starting tile
  public function getRect(sx: Int, sy: Int): _Room 
    {
      var w = 0, h = 0;
      var startTileID = _cells[sx][sy];
      while (true)
        {
          w++;
          if (w > 100)
            {
              trace('rect too large?');
              break;
            }

          if (sx + w > this.width)
            break;
          if (_cells[sx + w][sy] != startTileID)
            break;
        }
      while (true)
        {
          h++;
          if (h > 100)
            {
              trace('rect too large?');
              break;
            }

          if (sy + h > this.height)
            break;
          if (_cells[sx][sy + h] != startTileID)
            break;
        }
      w--;
      h--;
      return {
        id: -1,
        x1: sx,
        y1: sy,
        x2: sx + w,
        y2: sy + h,
        w: w + 1,
        h: h + 1,
      }
    }
/*
// add event object to area
  public function addEventObject(id: String, infoID: String): EventObject
    {
      // generate area if it's not yet generated
      if (!isGenerated)
        generate();

      // default
      var loc = findEmptyLocation();
      var o = addEventObjectInternal(loc.x, loc.y, id, infoID);
      return o;
    }*/

// add event object (low-level)
// NOTE: assumes that area was already generated
  public function addEventObject(ox: Int, oy: Int, name: String, infoID: String): EventObject
    {
      game.debug('!!! event obj ' + id +
        ' loc: (' + ox + ',' + oy +
        ') area: (' + this.x + ',' + this.y + ')');
      var o = new EventObject(game, this.id, ox, oy, name, infoID);
      // hide object if it's not in the current area
      if (game.area != this)
        o.hide();
      addObject(o);
      return o;
    }

// spawn generic pickup item
  public function addItem(ox: Int, oy: Int, item: _Item, ?imageID: Int = 0, ?canActivateNear: Bool = false): Pickup
    {
      if (imageID == 0)
        imageID = Const.FRAME_PICKUP;
      var itemName = (game.player.knowsItem(item.info.id) ?
        item.name : item.info.unknown);
      var o: Pickup = null;
      if (canActivateNear)
        o = untyped new GenericPickupNear(game, id, ox, oy, imageID);
      else o = untyped new GenericPickup(game, id, ox, oy, imageID);
      o.name = itemName;
      o.item = item;
      // hide object if it's not in the current area
      if (game.area != this)
        o.hide();
      addObject(o);
      if (game.area == this)
        o.entity.setPosition(o.x, o.y);
      return o;
    }

// add object to area (low-level)
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
              !(game.playerArea.x == xo + dx &&
                game.playerArea.y == yo + dy))
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

// replace area type and reinit
  public function setType(t: _AreaType)
    {
      typeID = t;
      info = WorldConst.getAreaInfo(typeID);
      width = info.width - 10 + 10 * Std.random(2);
      height = info.height - 10 + 10 * Std.random(2);

      // set name
      name = info.name;
      if (typeID == AREA_MILITARY_BASE)
        name = NameConst.generate('%baseA1% %baseB1%');
      else if (typeID == AREA_FACILITY)
        name = NameConst.generate('%tree1% %geo1% %lab1%');
    }

// update area type after change
  public function updateType()
    {
      setType(typeID);

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
  public function getAIByID(id: Int): AI
    {
      for (ai in _ai)
        if (ai.id == id)
          return ai;
      return null;
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

// check if you can see through this tile 
  public function canSeeThrough(x: Int, y: Int): Bool
    {
      if (x < 0 || y < 0 || x >= width || y >= height)
        return false;
      return (Const.TILE_SEETHROUGH[_cells[x][y]] == 1);
    }

// check if tile is walkable
  public function isWalkable(x: Int, y: Int): Bool
    {
      if (x < 0 || y < 0 || x >= width || y >= height)
        return false;
//      trace(x + ',' + y + ' ' + _cells[x][y]);
      return (Const.TILE_WALKABLE[_cells[x][y]] == 1);
    }

// check if x1, y1 sees x2, y2
// bresenham copied from wikipedia with one slight modification
  public function isVisible(x1: Int, y1: Int, x2: Int, y2: Int, ?doTrace: Bool)
    {
      var startx = x1, starty = y1, finx = x2, finy = y2;
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
              ok = canSeeThrough(yy, xx);

              // always see through start and finish
              if (startx == yy && starty == xx)
                ok = true;
              else if (finx == yy && finy == xx)
                ok = true;
            }
          else
            {
//              if (doTrace)
//                trace(xx + ',' + yy);
              ok = canSeeThrough(xx, yy);

              // always see through start and finish
              if (startx == xx && starty == yy)
                ok = true;
              else if (finx == xx && finy == yy)
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
//      if (ai.isNPC)
//        game.debug('AI remove ' + ai.id);
      // event: despawn live AI
      if (ai.state != AI_STATE_DEAD &&
          ai != game.player.host &&
          // only called if player in the same area
          game.area == this)
        ai.onRemove();

      if (ai.npc != null)
        ai.npc.ai = null;
      ai.entity = null;
      _ai.remove(ai);
      
      // cultists need to update the ai data in members
      if (ai.isCultist)
        {
          var cult = game.getCultByID(ai.cultID);
          cult.onRemoveAI(ai);
        }
      // remove from all enemies lists
      for (tmp in _ai)
        if (Lambda.has(tmp.enemies, ai.id))
          tmp.enemies.remove(ai.id);
    }


// TURN: area time passage - ai actions, object events
  public function turn()
    {
      // turns spent in this area
      turns++;

      // AI logic
      for (ai in _ai)
        {
          ai.turnInternal();
          if (game.isInputLocked())
            return;
        }

      // object logic
      for (o in _objects)
        o.turn();

      // call turn for area view
      game.scene.area.turn();

      turnSpawnCommonAI(); // spawn AI
      turnSpawnMoreAI(); // spawn AI related to area alertness
      turnSpawnNPC(); // spawn NPC AI
      turnSpawnClues(); // spawn clues
      turnSpawnTeam(); // spawn team agents
      turnAlertness(); // decrease alertness

      // mission turn processing
      if (isMissionArea())
        game.cults[0].turnMission();
    }


// spawn group team members
  function turnSpawnTeam()
    {
      var team = game.group.team;
      if (team == null ||
          isHabitat ||
          !info.isInhabited)
        return;

      // do not spawn team members in the first area (a little help for newbie players)
      if (!game.goals.completed(GOAL_ENTER_SEWERS))
        return;

      // do not spawn in mission areas
      if (isMissionArea())
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

      game.debug('Team member spawned');
    }


// spawn some clues
  function turnSpawnClues()
    {
      if (!game.player.vars.timelineEnabled ||
          events.length == 0)
        return;

      // NOTE: hmm, it appears that if player stumbles into event location by
      // chance, the clues will spawn anyway. it wasn't intentional but
      // but i'll leave it like that.

      // get the event for which to spawn clues for
      var e = null;
      for (ev in events)
        {
          // all event notes and npcs names/jobs known
          if (ev.notesKnown() &&
              ev.npcNamesOrJobsKnown())
            continue;

          e = ev;

          // i could put events into a temp array but not much need to
          if (Std.random(2) == 0)
            break;
        }
      if (e == null)
        return;

      // get number of clues already spawned
      // and despawn the ones that are far from player
      var cnt = 0;
      var radius = game.player.vars.listenRadius;
      for (o in _objects)
        if (o.item != null &&
            o.item.info.type == 'readable')
          {
            // in radius
            if (game.playerArea.distanceSquared(o.x, o.y) < radius * radius)
              {
                cnt++;
                continue;
              }
            // player sees it
            if (game.playerArea.sees(o.x, o.y))
              {
                cnt++;
                continue;
              }
            // min timeout
            if (game.turns - o.creationTime < 10)
              {
                cnt++;
                continue;
              }

            // despawn readable
            removeObject(o);
          }

      // labs
      if (info.id == AREA_FACILITY)
        {
          var maxSpawn = 4 - cnt;
          if (maxSpawn <= 0)
            return;

          // get all close clue spawn points
          var spawns = [];
          for (pt in clueSpawnPoints)
            {
              // must be on screen
              if (!inVisibleRect(pt.x, pt.y))
                continue;

              // must not be visible to player as a parasite
              if (game.player.state != PLR_STATE_HOST &&
                  Const.distanceSquared(game.playerArea.x, game.playerArea.y, pt.x, pt.y) < 6 * 6)
                continue;

              // must not be visible to player when possessing a host
              if (game.player.state == PLR_STATE_HOST &&
                  isVisible(game.playerArea.x, game.playerArea.y, pt.x, pt.y))
                continue;

              // already an object there
              if (hasObjectAt(pt.x, pt.y))
                continue;

              spawns.push(pt);
            }
          if (spawns.length == 0)
            {
//              trace('cannot spawn clue, no spots');
              return;
            }

          // spawn items
          for (_ in 0...maxSpawn)
            {
              if (spawns.length == 0)
                return;
              var info = ItemsConst.getInfo(Std.random(100) < 80 ? 'paper' : 'book');

              // find empty clue location
              var loc = spawns[Std.random(spawns.length)];
              spawns.remove(loc);

              // spawn object
              var tiles = null;
              if (info.id == 'paper')
                tiles = Const.CHEM_LABS_DOCUMENTS[Std.random(Const.CHEM_LABS_DOCUMENTS.length)];
              else if (info.id == 'book')
                tiles = Const.CHEM_LABS_BOOKS[Std.random(Const.CHEM_LABS_BOOKS.length)];
              var o = new Document(game, this.id, loc.x, loc.y,
                tiles.row, Std.random(tiles.amount));
              o.name = info.names[Std.random(info.names.length)];
              o.item = {
                game: game,
                id: info.id,
                name: o.name,
                info: info,
                event: e
              };
              addObject(o);
            }
        }

      // default - generic algorithm for streets
      else
        {
          // streets have minimal amount of clues
          var maxClues = 5;
          switch (info.id)
            {
              case AREA_CITY_HIGH:
                maxClues = 2;
              case AREA_CITY_MEDIUM:
                maxClues = 1;
              case AREA_CITY_LOW:
                maxClues = 1;
              default:
                // military bases
                maxClues = 5;
            }
          var maxSpawn = maxClues - cnt;
          var info = ItemsConst.getInfo(Std.random(100) < 80 ? 'paper' : 'book');
          for (_ in 0...maxSpawn)
            {
              var loc = findUnseenEmptyLocation();
              if (loc.x < 0)
                {
                  trace('Area.turnSpawnClues(): no free spot for another ' +
                    info.id + ', please report');
                  return;
                }

              var o: AreaObject = Type.createInstance(info.areaObjectClass,
                [ game, this.id, loc.x, loc.y ]);
              o.name = info.names[Std.random(info.names.length)];
              o.item = {
                game: game,
                id: info.id,
                name: o.name,
                info: info,
                event: e
              };
              addObject(o);
            }
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

// spawn guards (done once on enter)
// guards stand on their post and do not despawn when unseen
  function spawnGuards()
    {
      // large chance on important points
      for (pt in importantGuardSpawnPoints)
        {
          if (Std.random(100) > 75)
            continue;
          var ai = spawnAI('security', pt.x, pt.y);
          ai.isGuard = true;
          ai.guardTargetX = pt.x;
          ai.guardTargetY = pt.y;
        }

      // small chance on normal points
      for (pt in guardSpawnPoints)
        {
          if (Std.random(100) > 10)
            continue;
          var ai = spawnAI('security', pt.x, pt.y);
          ai.isGuard = true;
          ai.guardTargetX = pt.x;
          ai.guardTargetY = pt.y;
        }
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
            game.debug('spawn npc ' + n.id + ' (ai: ' + ai.id + ')');
            ai.setNPC(n);

            // spawn up to maxSpawn npcs
            i++;
            if (i >= maxSpawn)
              break;
          }
    }

/* quick try.haxe.org (https://try.haxe.org/#C38a6393) test:
class Test {
  static function main() {
    var commonAI = 8;
    var constCells = 650;
    for (i in 0...35)
    {
      if (i == 13)
        trace('===');
      trace((i * 50) + ' | v0.7: ' + Std.int(commonAI * i * 50 / constCells) +
            ', sqrt: ' + Std.int(commonAI * Math.sqrt(i * 50 / constCells)) +
            ', root3:' + Std.int(commonAI * Math.pow(i * 50 / constCells, 0.3)) +
            ', rootX:' + Std.int(commonAI * Math.pow(i * 50 / constCells, 0.7))
           );    
    }
  }
}

0 | v0.7: 0, sqrt: 0, root3:0, rootX:0
50 | v0.7: 0, sqrt: 2, root3:3, rootX:1
100 | v0.7: 1, sqrt: 3, root3:4, rootX:2
150 | v0.7: 1, sqrt: 3, root3:5, rootX:2
200 | v0.7: 2, sqrt: 4, root3:5, rootX:3
250 | v0.7: 3, sqrt: 4, root3:6, rootX:4
300 | v0.7: 3, sqrt: 5, root3:6, rootX:4
350 | v0.7: 4, sqrt: 5, root3:6, rootX:5
400 | v0.7: 4, sqrt: 6, root3:6, rootX:5
450 | v0.7: 5, sqrt: 6, root3:7, rootX:6
500 | v0.7: 6, sqrt: 7, root3:7, rootX:6
550 | v0.7: 6, sqrt: 7, root3:7, rootX:7
600 | v0.7: 7, sqrt: 7, root3:7, rootX:7
===
650 | v0.7: 8, sqrt: 8, root3:8, rootX:8
700 | v0.7: 8, sqrt: 8, root3:8, rootX:8
750 | v0.7: 9, sqrt: 8, root3:8, rootX:8
800 | v0.7: 9, sqrt: 8, root3:8, rootX:9
850 | v0.7: 10, sqrt: 9, root3:8, rootX:9
900 | v0.7: 11, sqrt: 9, root3:8, rootX:10
950 | v0.7: 11, sqrt: 9, root3:8, rootX:10
1000 | v0.7: 12, sqrt: 9, root3:9, rootX:10
1050 | v0.7: 12, sqrt: 10, root3:9, rootX:11
1100 | v0.7: 13, sqrt: 10, root3:9, rootX:11
1150 | v0.7: 14, sqrt: 10, root3:9, rootX:11
1200 | v0.7: 14, sqrt: 10, root3:9, rootX:12
1250 | v0.7: 15, sqrt: 11, root3:9, rootX:12
1300 | v0.7: 16, sqrt: 11, root3:9, rootX:12
1350 | v0.7: 16, sqrt: 11, root3:9, rootX:13
1400 | v0.7: 17, sqrt: 11, root3:10, rootX:13
1450 | v0.7: 17, sqrt: 11, root3:10, rootX:14
1500 | v0.7: 18, sqrt: 12, root3:10, rootX:14
1550 | v0.7: 19, sqrt: 12, root3:10, rootX:14
1600 | v0.7: 19, sqrt: 12, root3:10, rootX:15
1650 | v0.7: 20, sqrt: 12, root3:10, rootX:15
1700 | v0.7: 20, sqrt: 12, root3:10, rootX:15
   */
// max number of visible AI
  public function getMaxAICoef(): Float
    {
      return (game.scene.area.emptyScreenCells <
        WorldConst.AREA_AI_CELLS ? 0.6 : 0.3);

    }
  public function getMaxAI(): Int
    {
      return Std.int(info.commonAI *
        Math.pow(1.0 * game.scene.area.emptyScreenCells /
          WorldConst.AREA_AI_CELLS, getMaxAICoef()));
    }

// spawn new AI, called each turn
  function turnSpawnCommonAI()
    {
      if (info.commonAI == 0)
        return;

      // get number of common AI excluding player
      var cnt = 0;
      for (ai in _ai)
        if (ai.isCommon &&
            !ai.isGuard &&
            !ai.parasiteAttached)
          cnt++;

      // calc max possible number of AI
      var maxAI = getMaxAI();
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

      for (_ in 0...maxSpawn)
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

          // spawns AI at spot unseen by player
          spawnUnseenAI(type, true);
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
        if (!ai.isCommon &&
            !ai.isGuard &&
            !ai.parasiteAttached)
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
      for (_ in 0...maxSpawn)
        spawnUnseenAI(info.lawType, false);
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

      // special logic for "civilian" type
      if (type == 'civilian' &&
          (typeID == AREA_CITY_LOW ||
           typeID == AREA_CITY_MEDIUM))
        {
          var crimeChance = (typeID == AREA_CITY_LOW ? 30 : 10);
          if (highCrime)
            crimeChance += 30;
          if (Std.random(100) < crimeChance)
            {
              // pick specific type
              var roll = Std.random(100);
              if (roll < 20) // 20%
                type = 'prostitute';
              else if (roll < 50) // 30%
                type = 'thug';
              else type = 'bum'; // 50%
            }
        }

      // spot is empty and invisible to player, spawn ai
      var ai = spawnAI(type, loc.x, loc.y);
      ai.isCommon = isCommon;
      return ai;
    }

// spawn AI (both from command-line and internally)
  public static var aiTypes = [
    'agent', 'blackops', 'bum (hobo)', 'civilian (civ)',
    'dog', 'police (cop)', 'prostitute (pro)', 'soldier',
    'security (sec)', 'scientist (sci)', 'team',
    'thug',
  ];
  public function spawnAI(type: String, x: Int, y: Int, ?doAddAI:Bool = true): AI
    {
      var ai = game.createAI(type, x, y);
      // add chat clues
      game.player.chat.initClues(ai);
      if (doAddAI)
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


// check AI visibility
  public inline function updateVisibility()
    {
      // NOTE: only used for "player noticed" check now
      if (game.player.state == PLR_STATE_HOST)
        for (ai in _ai)
          {
            var v = isVisible(game.playerArea.x,
              game.playerArea.y, ai.x, ai.y);
            // noticed by player for the first time
            if (!ai.wasNoticed && v &&
                inVisibleRect(ai.x, ai.y))
              {
                ai.wasNoticed = true;
                ai.onNotice();
              }
          }
      // change tiles according to los
      game.scene.area.updateVisibility();
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

// get all AIs with a given type excluding player host
  public function getAIWithType(t: String): List<AI>
    {
      var tmp = new List<AI>();
      for (ai in _ai)
        {
          if (ai.type != t)
            continue;
          if (game.player.state == PLR_STATE_HOST &&
              game.player.host == ai)
            continue;
          tmp.add(ai);
        }
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
      return '[' + id + '] (' + x + ',' + y + '): ' + typeID + ' alertness:' + alertness;
    }


// ========================== SETTERS ====================================

  function get_parent(): AreaGame
    {
      if (parentID < 0)
        return null;
      else return game.world.get(0).get(parentID);
    }

  function get_alertness()
    { return _alertness; }

  function set_alertness(v: Float)
    {
      var mod = v - _alertness;
      // some areas raise alertness faster or slower
      if (game.isInited)
        {
          mod *= info.alertnessMod;
          v = _alertness + mod;
        }
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

 // check if this area is a mission area
 public function isMissionArea(): Bool
   {
     return game.cults[0].ordeals.isMissionArea(this);
   }

 // get area mission
 public function getAreaMission(): cult.Mission
   {
     return game.cults[0].ordeals.getAreaMission(this);
   }
}
