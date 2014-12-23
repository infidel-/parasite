// tiled area view

import com.haxepunk.Entity;
import com.haxepunk.HXP;
import com.haxepunk.graphics.Tilemap;
import ai.*;
import objects.*;
import entities.EffectEntity;


class Area
{
  var game: Game; // game state link

  var _tilemap: Tilemap;
  var _ai: List<AI>; // AI list
  var _objects: Map<Int, AreaObject>; // area objects list
  var _effects: List<EffectEntity>; // visual effects list
  var _cells: Array<Array<Int>>; // cell types
  var _pathEngine: aPath.Engine;
  var area: RegionArea; // region area link

  public var width: Int; // area width, height in cells
  public var height: Int;
  public var entity: Entity; // area entity
  public var manager: AreaManager; // area event manager
  public var player: PlayerArea; // game player (area mode)
  public var debug: DebugArea; // debug actions (area mode)

  public function new (g: Game)
    {
      game = g;
      _tilemap = null;
      width = 0;
      height = 0;

      entity = new Entity();
      entity.layer = Const.LAYER_TILES;

      manager = new AreaManager(g);
      player = new PlayerArea(g, this);
      debug = new DebugArea(g, this);
    }


// event: player leaves area
  public function onLeave()
    {
      // count all bodies and discover then in bulk
      var totalPoints = 0;
      var totalBodies = 0;
      for (o in _objects)
        if (o.type == 'body')
          {
            var body: BodyObject = untyped o;
            totalPoints += body.organPoints;
            totalBodies++;
          }

      // notify world about bodies discovered
      if (totalBodies == 1)
        game.region.manager.onBodyDiscovered(area, totalPoints);

      else if (totalBodies > 0)
        game.region.manager.onBodiesDiscovered(area, totalBodies, totalPoints);

      // clear all effects
      for (eff in _effects)
        {
          game.scene.remove(eff);
          _effects.remove(eff);
        }
    }


// set new area
  public function setArea(a: RegionArea)
    {
      area = a;
      width = area.width;
      height = area.height;

      if (_tilemap != null) // clear old graphic
        entity.graphic = null;

      _ai = new List<AI>();
      _objects = new Map<Int, AreaObject>();
      _effects = new List<EffectEntity>();
      _tilemap = new Tilemap("gfx/tileset.png",
        width * Const.TILE_WIDTH, height * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entity.addGraphic(_tilemap);

      // generate new area
      generate();

      // update player position 
      var loc = findEmptyLocation();
      if (game.player.state == PLR_STATE_HOST)
        {
          player.entity.visible = false;
          game.scene.add(game.player.host.entity);
          game.player.host.setPosition(loc.x, loc.y);
          _ai.add(game.player.host);
        }
      player.moveTo(loc.x, loc.y);

      player.ap = 2; // renew AP
      area.alertnessMod = 0; // clear alertness counter

      // hack: add sewers hatch right under player if this is not at the game start
      if (game.turns > 0)
        {
          var o = new SewerHatch(game, loc.x, loc.y);
          addObject(o);
/*
          Const.todo('!!!remove this!!!');
          var info = ConstItems.getInfo('paper');
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
*/
          // remove any adjacent sewer hatches
          for (y in -3...3)
            for (x in -3...3)
              {
                var olist = getObjectsAt(loc.x + x, loc.y + y);
                for (o2 in olist)
                  if (o2 != o && o2.type == o.type)
                    removeObject(o2);
              }
        }
    }


// get current area info
  public inline function getArea(): RegionArea
    { return area; }


// show gui
  public function show()
    {
      entity.visible = true;
      if (game.player.state != PLR_STATE_HOST)
        player.entity.visible = true;

      game.scene.updateCamera(); // center camera on player

      // update AI and objects visibility to player
      updateVisibility();
    }


// hide gui
  public function hide()
    {
      entity.visible = false;
      player.entity.visible = false;

      for (ai in _ai)
        removeAI(ai);

      for (o in _objects)
        removeObject(o);
    }


// generate a new area map
  function generate()
    {
      _cells = new Array<Array<Int>>();
      for (i in 0...width)
        _cells[i] = [];

      // clear map
      for (y in 0...height)
        for (x in 0...width)
          setType(x, y, Const.TILE_GROUND);

      generateBuildings();
      generateObjects();

      // set path info 
      _pathEngine = new aPath.Engine(this, width, height);
    }


// generate buildings
  function generateBuildings()
    {
      // buildings
      for (y in 1...height)
        for (x in 1...width)
          {
            if (Math.random() > area.info.buildingChance)
              continue;

            // size
            var sx = 5 + Std.random(10);
            var sy = 5 + Std.random(10);

            if (x + sx > width - 1)
              sx = width - 1 - x;
            if (y + sy > height - 1)
              sy = height - 1 - y;

            if (sx < 2)
              continue;
            if (sy < 2)
              continue;

//            var cell = get(x,y);

            // check for adjacent buildings
            var ok = true;
            for (dy in -2...sy + 3)
              for (dx in -2...sx + 3)
                {
                  if (dx == 0 && dy == 0)
                    continue;
                  //var cell = get(x + dx, y + dy);
                  var cellType = getType(x + dx, y + dy);
                  if (cellType == "building")
                    {
                      ok = false;
                      break;
                    }
                }

            if (!ok)
              continue;
  
            // draw a building rect
            for (dy in 0...sy)
              for (dx in 0...sx)
                {
                  var cellType = getType(x + dx, y + dy);
                  if (cellType == null)
                    continue;

                  setType(x + dx, y + dy, Const.TILE_BUILDING);
                }
          }
    }


// generate objects
  function generateObjects()
    {
      var info = area.info;

      // spawn all objects
      for (objInfo in info.objects)
        for (i in 0...objInfo.amount)
          {
            // find free spot that is not close to another object like this
            var loc = null;
            var cnt = 0;
            while (true)
              {
                loc = findEmptyLocation();
                cnt++;
                if (cnt > 500)
                  {
                    trace('Area.generateObjects(): no free spot for another ' + 
                      objInfo.id + ', please report');
                    return;
                  }

                // check for close objects
                var ok = true;
                for (y in -3...3)
                  for (x in -3...3)
                    {
                      var olist = getObjectsAt(loc.x + x, loc.y + y);
                      for (o in olist)
                        if (o.type == objInfo.id)
                          {
                            ok = false;
                            break;
                          }

                      if (!ok)
                        break;
                    }

                if (ok)
                  break;
              }

            var o: AreaObject = null;
            if (objInfo.id == 'sewer_hatch')
              o = new SewerHatch(game, loc.x, loc.y);
              
            else throw 'unknown object type: ' + objInfo.id;

            addObject(o);
          }
    }

/*
// create object with this type
  public function createObject(x: Int, y: Int, type: String, parentType: String): AreaObject
    {
      var o = new AreaObject(game, x, y);
      o.type = type;
      o.createEntity(parentType);
      _objects.set( o.id, o);

      return o;
    }
*/

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
      game.scene.remove(o.entity); 
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

          var x = rect.x1 + Std.random(rect.x2);
          var y = rect.y1 + Std.random(rect.y2);

          // must be empty ground tile
          if (getType(x, y) != 'ground')
            continue;

          // must not have ai
          if (getAI(x, y) != null)
            continue;

          // must not be visible to player as a parasite
          if (game.player.state != PLR_STATE_HOST &&
              HXP.distanceSquared(player.x, player.y, x, y) < 6 * 6)
            continue;

          // must not be visible to player when possessing a host
          if (game.player.state == PLR_STATE_HOST &&
              isVisible(player.x, player.y, x, y))
            continue;

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
          if (getType(x, y) != 'ground')
            continue;

          if (getAI(x, y) != null)
            continue;

          break;
        }

      return { x: x, y: y };
    }


// find empty location on map near xo,yo (to spawn stuff)
  public function findEmptyLocationNear(xo: Int, yo: Int): { x: Int, y: Int }
    {
      // make a temp list of empty spots in square radius 3
      var tmp = [];
      for (dy in -3...3)
        for (dx in -3...3)
          if (getType(xo + dx, yo + dy) == 'ground' && 
              getAI(xo + dx, yo + dy) == null &&
              !(player.x == xo + dx && player.y == yo + dy))
            tmp.push({ x: xo + dx, y: yo + dy });

      // no empty cells found
      if (tmp.length == 0)
        return null;

      return tmp[Std.random(tmp.length)];
    }


// get cell type of this cell
  public function getType(x: Int, y: Int): String
    {
      if (x < 0 || y < 0 || x >= width || y >= height)
        return null;
      return Const.TILE_TYPE[_cells[x][y]];

//      var index = _tilemap.getTile(x, y);
//      return Const.TILE_TYPE[index];
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
  inline function setType(x: Int, y: Int, index: Int)
    {
      _tilemap.setTile(x, y, index);
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
      if (ai.npc != null)
        ai.npc.ai = null;
      game.scene.remove(ai.entity);
      _ai.remove(ai);
    }


// TURN: area time passage - ai actions, object events
  public inline function turn()
    {
      // AI logic
      for (ai in _ai)
        ai.turn();

      // object logic
      for (o in _objects)
        o.turn();

      // effect removal
      for (e in _effects)
        {
          e.turns--;
          if (e.turns <= 0)
            {
              game.scene.remove(e);
              _effects.remove(e);
            }
        }

      turnSpawnAI(); // spawn AI
      turnSpawnMoreAI(); // spawn AI related to area alertness
      turnSpawnNPC(); // spawn NPC AI
      turnSpawnClues(); // spawn clues
      turnAlertness(); // decrease alertness
    }


// spawn some clues
  function turnSpawnClues()
    {
      if (game.timeline.isLocked || area.event == null)
        return;

      // all event notes and npcs names/jobs known, stop spawning clues
      if (area.event.notesKnown() && area.event.npcNamesOrJobsKnown())
        return;

      // get number of clues already spawned
      var cnt = 0;
      for (o in _objects)
        if (o.item != null && o.item.info.type == 'readable')
          cnt++;

      var maxSpawn = 5 - cnt;

      var info = ConstItems.getInfo('paper');
      for (i in 0...maxSpawn)
        {
          var loc = findUnseenEmptyLocation();
          if (loc.x < 0)
            {
              trace('Area.turnSpawnClues(): no free spot for another ' + 
                info.id + ', please report');
              return;
            }

          var o = new Paper(game, loc.x, loc.y);
          o.item = {
            id: 'paper',
            name: info.names[Std.random(info.names.length)],
            info: info,
            event: area.event
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

      area.alertness -= 0.1;
    }


// spawn NPC AI each turn
  function turnSpawnNPC()
    {
      // no npcs here
      if (area.npc.length == 0)
        return;
  
      // count total npcs with photo known and alive
      var total = 0;
      for (n in area.npc)
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
      for (n in area.npc)
        // alive, unspawned and job/photo known
        if (n.jobKnown && !n.isDead && n.ai == null)
          {
            var ai = spawnUnseenAI(n.type, true);
            if (ai == null)
              break;
            n.ai = ai;
            ai.event = n.event;
            ai.job = n.job;
            ai.npc = n;
            ai.name.real = n.name;
            ai.name.realCapped = n.name;
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
// will spawn AI depending on area interest/alertness
  function turnSpawnAI()
    {
      var info = area.info;

      // get number of common AI
      var cnt = 0;
      for (ai in _ai)
        if (ai.isCommon)
          cnt++;

      // there are enough AI already
      if (cnt > info.commonAI)
        return;

      // limit number of spawns per turn
      var maxSpawn = info.commonAI - cnt;
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
      var info = area.info;

      // get number of uncommon AI (spawned by alertness logic)
      var cnt = 0;
      for (ai in _ai)
        if (!ai.isCommon)
          cnt++;

      // calculate the actual number to spawn according to the area alertness
      var uncommonAI = Std.int(info.uncommonAI * area.alertness / 100.0);

      // there are enough uncommon AI already
      if (cnt > uncommonAI)
        return;

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
//      else if (type == 'civilian')
      else if (type == 'civilian' || type == 'agent')
        ai = new CivilianAI(game, loc.x, loc.y);
      else if (type == 'police')
        ai = new PoliceAI(game, loc.x, loc.y);
      else if (type == 'soldier')
        ai = new SoldierAI(game, loc.x, loc.y);
      else throw 'spawnUnseenAI(): AI type [' + type + '] unknown';

      ai.isCommon = isCommon;
      addAI(ai);

      return ai;
    }


// update AI visibility
  public inline function updateVisibility()
    {
      if (game.player.state == PLR_STATE_HOST)
        updateVisibilityHost();
      else updateVisibilityParasite();
    }


// get visible rectangle for this area
  function getVisibleRect(): { x1: Int, y1: Int, x2: Int, y2: Int }
    {
      var rect = { 
        x1: Std.int(HXP.camera.x / Const.TILE_WIDTH) - 1,
        y1: Std.int(HXP.camera.y / Const.TILE_HEIGHT) - 1,
        x2: Std.int((HXP.camera.x + HXP.windowWidth) / Const.TILE_WIDTH) + 2,
        y2: Std.int((HXP.camera.y + HXP.windowHeight) / Const.TILE_HEIGHT) + 2
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


// update visible area (also AI, objects visibility)
// host version
  function updateVisibilityHost()
    {
      // calculate visible rectangle
      var rect = getVisibleRect();

      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          if (!game.player.vars.losEnabled || 
              isVisible(player.x, player.y, x, y))
              _tilemap.setTile(x, y, _cells[x][y]);
          else _tilemap.setTile(x, y, Const.TILE_HIDDEN);

      for (ai in _ai)
        ai.entity.visible = 
          (game.player.vars.losEnabled ? isVisible(player.x, player.y, ai.x, ai.y) : true);

      for (obj in _objects)
        obj.entity.visible =
          (game.player.vars.losEnabled ? isVisible(player.x, player.y, obj.x, obj.y) : true);
    }


// update visible area (also AI, objects visibility)
// parasite version
// parasite only sees one tile around him but "feels" AIs in a larger radius
  function updateVisibilityParasite()
    {
      // calculate visible rectangle
      var rect = getVisibleRect();

      // set visibility for all tiles in that area
      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          if (Math.abs(player.x - x) < 2 &&
              Math.abs(player.y - y) < 2)
            _tilemap.setTile(x, y, _cells[x][y]);
          else _tilemap.setTile(x, y, Const.TILE_HIDDEN);

      for (ai in _ai)
        if (game.player.vars.losEnabled)
          ai.entity.visible = 
            (HXP.distanceSquared(player.x, player.y, ai.x, ai.y) < 6 * 6);
        else ai.entity.visible = true;

      for (obj in _objects)
        if (game.player.vars.losEnabled)
          obj.entity.visible = 
            (HXP.distanceSquared(player.x, player.y, obj.x, obj.y) < 6 * 6);
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
             !(player.x == nx && player.y == ny));
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
        if (HXP.distanceSquared(x, y, ai.x, ai.y) <= dist * dist &&
            (!los || game.area.isVisible(ai.x, ai.y, x, y)))
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
        if (HXP.distanceSquared(x, y, o.x, o.y) <= dist * dist &&
            (!los || game.area.isVisible(o.x, o.y, x, y)))
          tmp.add(o);

      return tmp;
    }


// get path from x1, y1 -> x2, y2
  public function getPath(x1: Int, y1: Int, x2: Int, y2: Int): Array<aPath.Node> 
    {
      if (!isWalkable(x1, y1) || !isWalkable(x2, y2) || (x1 == x2 && y1 == y2))
        return null;

      var t = Sys.time();
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


// add visual effect entity
  public function addEffect(x: Int, y: Int, turns: Int, frame: Int)
    {
      if (x >= width || y >= height || x < 0 || y < 0)
        return;

      var effect = new EffectEntity(game, x, y, turns, Const.ROW_EFFECT, frame);
      _effects.add(effect);
      game.scene.add(effect);
    }


// DEBUG: show all objects
  public inline function debugShowObjects()
    {
      for (o in _objects)
        trace(o);
    }


// DEBUG: set max area alertness
  public inline function debugSetMaxAlertness()
    {
      area.alertness = 100;
    }
}
