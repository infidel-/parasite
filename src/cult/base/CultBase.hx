// persistent Cultus Carnis living base state
package cult.base;

import ai.AI;
import ai.CustosAIData;
import const.CultBaseConst;
import cult.ordeals.BaseDefense;
import game.AreaGame;
import game.Game;
import objects.base.*;

class CultBase extends _SaveObject
{
  static var _ignoredFields = [ 'game' ];
  public var game: Game;
  public var areaID: Int;
  public var resources: CultBaseResources;
  public var income: CultBaseResources;
  public var storedBodies: Int;
  public var organs: Array<CultBaseOrgan>;
  public var custodes: Array<CustosAIData>;
  public var attackPressure: Int;
  public var activeDefenseMissionID: Int;
  public var activeDefenseTimer: Int;
  public var defensesSurvived: Int;
  public var cursorX: Int;
  public var cursorY: Int;
  public var selectedType: _CultBaseOrganType;
  public var selectedDirection: Int;
  public var rivalTurnCounter: Int;

  public function new(g: Game, areaID: Int, heartX: Int, heartY: Int)
    {
      game = g;
      init();
      this.areaID = areaID;
      cursorX = heartX;
      cursorY = heartY;
      resources = new CultBaseResources(30, 20, 20);
      var heart = new CultBaseOrgan(COR_NEFANDUM, areaID, heartX, heartY);
      organs.push(heart);
      createOrganObject(heart);
      game.logsg('Cor Nefandum begins to pulse with eldritch energy.');
    }

// init base fields
  public function init()
    {
      areaID = -1;
      resources = new CultBaseResources();
      income = new CultBaseResources();
      storedBodies = 0;
      organs = [];
      custodes = [];
      attackPressure = 0;
      activeDefenseMissionID = -1;
      activeDefenseTimer = 0;
      defensesSurvived = 0;
      cursorX = 0;
      cursorY = 0;
      selectedType = RAT_NEST;
      selectedDirection = 0;
      rivalTurnCounter = 0;
    }

// repair loaded references and defaults
  public function initPost(onLoad: Bool)
    {
      if (resources == null)
        resources = new CultBaseResources();
      if (income == null)
        income = new CultBaseResources();
      if (organs == null)
        organs = [];
      if (custodes == null)
        custodes = [];
      if (activeDefenseMissionID == 0)
        activeDefenseMissionID = -1;
      for (organ in organs)
        if (organ.id >= CultBaseOrgan._maxID)
          CultBaseOrgan._maxID = organ.id + 1;
    }

// repairs loaded base organ object parts
  public function loadPost()
    {
      syncOrganObjects();
    }

// runs one cult turn of base economy and pressure
  public function turn()
    {
      if (areaID < 0)
        return;

      // calculate income from organs and add to resources, respecting stockpile cap
      income = new CultBaseResources();
      for (organ in organs)
        {
          if (!organ.isWorking())
            continue;
          switch (organ.type)
            {
              case FLESH_BLOCK:
                income.flesh += 5 * organ.level;
              case RAT_NEST:
                income.flesh += 3 * organ.level;
                income.blood += organ.level;
                income.bone += organ.level;
              case CRUSHER:
                if (storedBodies > 0)
                  {
                    storedBodies--;
                    income.bone += 5 * organ.level;
                  }
              case GARBAGE_HEAP:
                if (storedBodies > 0)
                  {
                    storedBodies--;
                    income.flesh += 5 * organ.level;
                  }
                else income.flesh += 2 * organ.level;
              default:
            }
        }
      resources.add(income, stockpileCap());

      // heal custodes between attacks
      healCustodes();

      // increase pressure
      addPressure(1 + getHeartUpgradeCount());

      // run rival turns
      runRivalTurn();
      if (!income.isEmpty())
        game.logsg('Base income: ' + income.text() + '.');
    }

// returns current stockpile cap
  public function stockpileCap(): Int
    {
      return 100 + 50 * getHeartUpgradeCount();
    }

// returns true when one working organ of type exists
  public function hasWorkingOrgan(type: _CultBaseOrganType): Bool
    {
      for (organ in organs)
        if (organ.type == type && organ.isWorking())
          return true;
      return false;
    }

// returns the heart organ
  public function getHeart(): CultBaseOrgan
    {
      for (organ in organs)
        if (organ.type == COR_NEFANDUM)
          return organ;
      return null;
    }

// adds attack pressure and schedules defense when needed
  public function addPressure(value: Int, ?cultID: Int = -1)
    {
      if (activeDefenseMissionID >= 0)
        return;
      attackPressure += value;
      if (attackPressure < 30 ||
          activeDefenseMissionID >= 0)
        return;

      // schedule defense mission and reset pressure
      attackPressure -= 30;
      var ordeal = new BaseDefense(game, cultID);
      game.cults[0].ordeals.list.push(ordeal);
      activeDefenseMissionID = ordeal.missions[0].id;
      activeDefenseTimer = ordeal.timer;
      game.message({
        text: 'Heretics close on Cor Nefandum. Defend the base before the timer expires.',
        col: 'alert'
      });
    }

// places one new organ if resources and placement allow
  public function buildSelected(): Bool
    {
      var type = selectedType;
      var reason = validateBuild(type, cursorX, cursorY);
      if (reason != '')
        {
          game.actionFailed(reason);
          return false;
        }
      var cost = CultBaseConst.buildCost(type);
      if (!resources.canAfford(cost))
        {
          game.actionFailed('Not enough base resources.');
          return false;
        }
      resources.spend(cost);
      if (type == RIBGATE)
        removeRibwallAt(cursorX, cursorY);
      var organ = new CultBaseOrgan(type, areaID, cursorX, cursorY,
        selectedDirection);
      organs.push(organ);
      createOrganObject(organ);
      game.log('You shape ' + CultBaseConst.name(type) + '.');
      game.updateHUD();
      if (game.location == LOCATION_AREA)
        game.scene.area.draw();
      return true;
    }

// upgrades organ at cursor when possible
  public function upgradeAtCursor(): Bool
    {
      var organ = getOrganAt(cursorX, cursorY);
      if (organ == null)
        {
          game.actionFailed('No base organ at cursor.');
          return false;
        }
      var maxLevel = CultBaseConst.info(organ.type).maxLevel;
      if (organ.level >= maxLevel)
        {
          game.actionFailed('This organ cannot grow further.');
          return false;
        }
      var cost = organ.upgradeCost();
      if (!resources.canAfford(cost))
        {
          game.actionFailed('Not enough base resources.');
          return false;
        }
      resources.spend(cost);
      organ.level++;
      organ.broken = false;
      organ.health = organ.maxHealth();
      refreshOrganObject(organ);
      game.log('You strengthen ' + CultBaseConst.name(organ.type) + '.');
      game.updateHUD();
      return true;
    }

// repairs organ at cursor when possible
  public function repairAtCursor(): Bool
    {
      var organ = getOrganAt(cursorX, cursorY);
      if (organ == null)
        {
          game.actionFailed('No base organ at cursor.');
          return false;
        }
      if (organ.health >= organ.maxHealth() && !organ.broken)
        {
          game.actionFailed('This organ is whole.');
          return false;
        }
      var cost = organ.repairCost();
      if (!resources.canAfford(cost))
        {
          game.actionFailed('Not enough base resources.');
          return false;
        }
      resources.spend(cost);
      organ.health = organ.maxHealth();
      organ.broken = false;
      refreshOrganObject(organ);
      game.log('You mend ' + CultBaseConst.name(organ.type) + '.');
      game.updateHUD();
      return true;
    }

// damages an organ and handles broken/heart death states
  public function damageOrgan(organ: CultBaseOrgan, damage: Int)
    {
      organ.health -= damage;
      if (organ.health > 0)
        {
          if (organ.type == COR_NEFANDUM)
            game.log(Const.col('alert', 'Cor Nefandum is wounded!'));
          refreshOrganObject(organ);
          return;
        }
      organ.health = 0;
      if (organ.type == COR_NEFANDUM)
        {
          game.finish('lose', 'corNefandum', 'event/death');
          return;
        }
      organ.broken = true;
      refreshOrganObject(organ);
    }

// adds bodies to storage and returns overflow
  public function addBodies(amount: Int): Int
    {
      var cap = bodyCapacity();
      var room = cap - storedBodies;
      if (room < 0)
        room = 0;
      var added = amount;
      if (added > room)
        added = room;
      storedBodies += added;
      return amount - added;
    }

// creates custos at the cursor
  public function createCustos(type: _CustosType): Bool
    {
      if (!hasWorkingOrgan(CAULDRON))
        {
          game.actionFailed('A working Caldarium is required.');
          return false;
        }
      if (custodes.length >= custosCap())
        {
          game.actionFailed('Custodes capacity reached.');
          return false;
        }
      var cost = new CultBaseResources(10, 8, 0);
      if (!resources.canAfford(cost))
        {
          game.actionFailed('Not enough base resources.');
          return false;
        }
      if (!area().isWalkable(cursorX, cursorY) ||
          area().hasAI(cursorX, cursorY))
        {
          game.actionFailed('Custos needs a free tile.');
          return false;
        }
      resources.spend(cost);
      var ai = new ai.CustosAI(game, cursorX, cursorY, type);
      ai.custosID = ai.id;
      ai.guardTargetX = cursorX;
      ai.guardTargetY = cursorY;
      var data = new CustosAIData(game);
      data.updateFromAI(ai, areaID, cursorX, cursorY,
        'on custos creation');
      custodes.push(data);
      game.area.addAI(ai);
      game.log('A new Custos takes shape.');
      game.updateHUD();
      return true;
    }

// records custos data when it leaves or dies
  public function onRemoveAI(ai: AI)
    {
      var data = getCustos(ai.custosID);
      if (data == null)
        return;
      if (ai.state == AI_STATE_DEAD)
        custodes.remove(data);
      else
        {
          data.updateFromAI(ai, areaID, data.anchorX, data.anchorY,
            'on custos remove');
        }
    }

// spawns missing custodes when base area is entered
  public function onEnterArea()
    {
      if (game.area == null ||
          game.area.id != areaID)
        return;
      for (data in custodes)
        if (game.area.getAIByID(data.id) == null)
          spawnCustos(data);
    }

// updates custodes data when leaving base area
  public function onLeaveArea()
    {
      if (game.area == null ||
          game.area.id != areaID)
        return;
      for (ai in game.area.getAllAI())
        if (ai.isCustos)
          {
            var data = getCustos(ai.custosID);
            if (data != null)
              {
                data.updateFromAI(ai, areaID, data.anchorX, data.anchorY,
                  'on custos despawn');
              }
          }
    }

// populates HUD actions while base-building mode is active
  public function updateActionList()
    {
      game.ui.hud.addAction(action('baseExit', 'Exit Forma', function() {
        game.ui.hud.state = HUD_DEFAULT;
        game.updateHUD();
        game.scene.mouse.update(true);
        if (game.location == LOCATION_AREA)
          game.scene.area.draw();
        return true;
      }));
      var buildableTypes = CultBaseConst.buildableTypes.copy();
      buildableTypes.sort(function(a, b) {
        return Reflect.compare(CultBaseConst.name(a), CultBaseConst.name(b));
      });
      for (type in buildableTypes)
        {
          var organType = type;
          var label = CultBaseConst.name(type);
          if (selectedType == type)
            label = Const.col('white', label);
          game.ui.hud.addAction(action('baseSelect.' + type, label,
            function() {
              selectedType = organType;
              game.updateHUD();
              return true;
            }));
        }
      if (selectedType == SPINE_TURRET)
        game.ui.hud.addAction(action('baseDirection', directionName(),
          function() {
            selectedDirection = (selectedDirection + 1) % 4;
            game.updateHUD();
            return true;
          }));
      game.ui.hud.addAction(action('baseBuild', 'Build ' +
        CultBaseConst.name(selectedType), function() return buildSelected()));
      var organ = getOrganAt(cursorX, cursorY);
      if (organ != null)
        {
          game.ui.hud.addAction(action('baseUpgrade', 'Upgrade ' +
            CultBaseConst.name(organ.type), function() return upgradeAtCursor()));
          game.ui.hud.addAction(action('baseRepair', 'Repair ' +
            CultBaseConst.name(organ.type), function() return repairAtCursor()));
        }
      if (hasWorkingOrgan(CAULDRON))
        {
          game.ui.hud.addAction(action('baseFirmus', 'Craft Firmus',
            function() return createCustos(FIRMUS)));
          game.ui.hud.addAction(action('baseMordax', 'Craft Mordax',
            function() return createCustos(MORDAX)));
        }
    }

// moves the forma cursor by one bounded step
  public function moveCursor(dx: Int, dy: Int): Bool
    {
      return setCursor(cursorX + dx, cursorY + dy);
    }

// sets the forma cursor to a non-wall tile
  public function setCursor(x: Int, y: Int): Bool
    {
      var area = area();
      if (x < 0)
        x = 0;
      if (y < 0)
        y = 0;
      if (x >= area.width)
        x = area.width - 1;
      if (y >= area.height)
        y = area.height - 1;
      if (!canUseCursorTile(x, y))
        return false;
      cursorX = x;
      cursorY = y;
      game.updateHUD();
      if (game.location == LOCATION_AREA)
        game.scene.area.draw();
      return true;
    }

// returns true when the forma cursor may select this terrain tile
  public function canUseCursorTile(x: Int, y: Int): Bool
    {
      var area = area();
      if (x < 0 ||
          y < 0 ||
          x >= area.width ||
          y >= area.height)
        return false;
      var tileset = game.scene.images.getTileset(area.getTilesetTypeID());
      return tileset != null && !tileset.isWallTile(area.getCellType(x, y));
    }

// returns HUD info block for base state
  public function hudInfo(): String
    {
      var organ = getOrganAt(cursorX, cursorY);
      var selected = CultBaseConst.name(selectedType) + ' cost ' +
        CultBaseConst.buildCost(selectedType).text();
      var ret = 'Base: F ' + resources.flesh +
        ', Bld ' + resources.blood +
        ', Bone ' + resources.bone +
        ' / ' + stockpileCap() +
        '<br/>Bodies: ' + storedBodies + '/' + bodyCapacity() +
        ', Pressure: ' + attackPressure +
        '<br/>Cursor: (' + cursorX + ',' + cursorY + ') ' + selected;
      if (organ != null)
        ret += '<br/>Here: ' + CultBaseConst.name(organ.type) +
          ' L' + organ.level + ' HP ' + organ.health + '/' +
          organ.maxHealth() + (organ.broken ? ' [broken]' : '');
      return ret + '<br/>' + readinessText();
    }

// returns base status text for cult window
  public function statusText(): String
    {
      return 'Level 2 base at area ' + areaID +
        '<br/>Flesh ' + resources.flesh +
        ', Blood ' + resources.blood +
        ', Bone ' + resources.bone +
        ' / ' + stockpileCap() +
        '<br/>Bodies ' + storedBodies + '/' + bodyCapacity() +
        ', Custodes ' + custodes.length + '/' + custosCap() +
        ', Pressure ' + attackPressure +
        (activeDefenseMissionID >= 0 ?
          '<br/>' + Const.col('alert', 'Base defense timer: ' + activeDefenseTimer) :
          '') +
        '<br/>' + readinessText();
    }

// returns organ at tile, including multi-tile footprints
  public function getOrganAt(x: Int, y: Int): CultBaseOrgan
    {
      for (organ in organs)
        for (pt in organ.footprint())
          if (pt.x == x && pt.y == y)
            return organ;
      return null;
    }

// finds nearest working organ from a tile
  public function getNearestWorkingOrgan(x: Int, y: Int): CultBaseOrgan
    {
      var best: CultBaseOrgan = null;
      var bestDist = 999999;
      for (organ in organs)
        {
          if (!organ.isWorking())
            continue;
          var dist = Const.distanceSquared(x, y, organ.x, organ.y);
          if (best == null || dist < bestDist)
            {
              best = organ;
              bestDist = dist;
            }
        }
      return best;
    }

// validates selected build position
  public function validateBuild(type: _CultBaseOrganType,
      x: Int, y: Int): String
    {
      if (type == COR_NEFANDUM)
        return 'Cor Nefandum already exists.';
      if (type == RIBGATE)
        {
          var existing = getOrganAt(x, y);
          if (existing == null ||
              existing.type != RIBWALL)
            return 'Porta Costarum must replace a ribwall.';
        }
      else if (getOrganAt(x, y) != null)
        return 'Tile already holds a base organ.';

      var area = area();
      var fp = CultBaseConst.footprint(type, x, y);
      for (pt in fp)
        {
          if (!isBuildFloorWalkable(pt.x, pt.y))
            return 'Footprint must be on walkable floor.';
          if (area.hasAI(pt.x, pt.y))
            return 'Footprint is occupied.';
          if (hasBlockingObject(pt.x, pt.y, type))
            return 'Footprint is blocked.';
        }
      return '';
    }

// returns Corpus Basilica readiness summary
  public function readinessText(): String
    {
      var organLevels = 0;
      var hasGrowth = false;
      var hasStorage = false;
      var hasCauldron = false;
      var defenses = 0;
      for (organ in organs)
        {
          if (organ.type == COR_NEFANDUM)
            continue;
          organLevels += organ.level;
          var info = CultBaseConst.info(organ.type);
          if (info.isGrowth)
            hasGrowth = true;
          if (organ.type == BODY_STORAGE)
            hasStorage = true;
          if (organ.type == CAULDRON)
            hasCauldron = true;
          if (info.isDefense)
            defenses++;
        }
      var heart = getHeartUpgradeCount();
      return Const.smallgray('Corpus Basilica: Heart ' + heart + '/3, organs ' +
        organLevels + '/10<br/>Growth ' + yes(hasGrowth) +
        ', storage ' + yes(hasStorage) +
        ', cauldron ' + yes(hasCauldron) +
        '<br/>Defenses ' + defenses + '/5, survived ' +
        defensesSurvived + '/2');
    }

// creates object for organ record
  function createOrganObject(organ: CultBaseOrgan)
    {
      var data = CultBaseConst.info(organ.type);
      for (dy in 0...data.h)
        for (dx in 0...data.w)
          createOrganObjectPart(organ, dx, dy, dy * data.w + dx);
    }

// creates one visual object part for an organ record
  function createOrganObjectPart(organ: CultBaseOrgan, dx: Int, dy: Int,
      partIndex: Int)
    {
      var ox = organ.x + dx;
      var oy = organ.y + dy;
      switch (organ.type)
        {
          case COR_NEFANDUM:
            new CorNefandum(game, areaID, ox, oy, organ.id, partIndex);
          case RIBWALL:
            new Ribwall(game, areaID, ox, oy, organ.id, partIndex);
          case RIBGATE:
            new Ribgate(game, areaID, ox, oy, organ.id, partIndex);
          case SPINE_TURRET:
            new SpineTurret(game, areaID, ox, oy, organ.id, partIndex);
          case BLOOD_TRAP:
            new BloodTrap(game, areaID, ox, oy, organ.id, partIndex);
          case FLESH_BLOCK:
            new FleshBlock(game, areaID, ox, oy, organ.id, partIndex);
          case RAT_NEST:
            new RatNest(game, areaID, ox, oy, organ.id, partIndex);
          case CRUSHER:
            new Crusher(game, areaID, ox, oy, organ.id, partIndex);
          case GARBAGE_HEAP:
            new GarbageHeap(game, areaID, ox, oy, organ.id, partIndex);
          case BODY_STORAGE:
            new BodyStorage(game, areaID, ox, oy, organ.id, partIndex);
          case CAULDRON:
            new Cauldron(game, areaID, ox, oy, organ.id, partIndex);
        }
    }

// refreshes visible object linked to organ
  function refreshOrganObject(organ: CultBaseOrgan)
    {
      var area = area();
      for (o in area.getObjects())
        if (o.type == 'base_organ')
          {
            var obj: BaseOrganObject = cast o;
            if (obj.organID == organ.id)
              {
                obj.syncOrganImage();
                if (obj.entity != null)
                  obj.updateImage();
                area.recalcTile(o.x, o.y);
              }
          }
    }

// ensures loaded organ records have all matching visual object parts
  function syncOrganObjects()
    {
      if (areaID < 0)
        return;
      var area = area();
      for (organ in organs)
        {
          var data = CultBaseConst.info(organ.type);
          for (partIndex in 0...data.w * data.h)
            {
              var dx = partIndex % data.w;
              var dy = Std.int(partIndex / data.w);
              var obj = getOrganObjectPart(organ, partIndex);
              if (obj == null)
                createOrganObjectPart(organ, dx, dy, partIndex);
              else
                {
                  obj.x = organ.x + dx;
                  obj.y = organ.y + dy;
                  obj.syncOrganImage();
                  if (obj.entity != null)
                    obj.updateImage();
                  area.recalcTile(obj.x, obj.y);
                }
            }
        }
    }

// finds one visual object part for an organ record
  function getOrganObjectPart(organ: CultBaseOrgan,
      partIndex: Int): BaseOrganObject
    {
      for (o in area().getObjects())
        if (o.type == 'base_organ')
          {
            var obj: BaseOrganObject = cast o;
            if (obj.organID == organ.id &&
                obj.basePartIndex == partIndex)
              return obj;
          }
      return null;
    }

// returns base area
  inline function area(): AreaGame
    {
      return game.region.get(areaID);
    }

// returns heart upgrade count
  function getHeartUpgradeCount(): Int
    {
      var heart = getHeart();
      if (heart == null)
        return 0;
      return heart.level - 1;
    }

// returns total body storage capacity
  function bodyCapacity(): Int
    {
      var cap = 0;
      for (organ in organs)
        if (organ.type == BODY_STORAGE &&
            organ.isWorking())
          cap += 8 * organ.level;
      return cap;
    }

// returns total custodes capacity
  function custosCap(): Int
    {
      var cap = 0;
      for (organ in organs)
        if (organ.type == CAULDRON && organ.isWorking())
          cap += 2 * organ.level;
      return cap;
    }

// heals stored custodes between attacks
  function healCustodes()
    {
      for (data in custodes)
        if (data.health < data.maxHealth)
          data.health++;
    }

// runs one simplified rival action every ten cult turns
  function runRivalTurn()
    {
      var alive = game.getRivalCults(true);
      if (alive.length == 0)
        return;
      rivalTurnCounter++;
      if (rivalTurnCounter < 10)
        return;
      rivalTurnCounter = 0;
      var rival = alive[Std.random(alive.length)];
      if (rival.rivalTactic == RIVAL_COMBAT)
        {
          addPressure(10, rival.id);
          game.logsg(rival.name + ' drives fighters toward the base.');
        }
      else
        {
          addPressure(5, rival.id);
          game.logsg(rival.name + ' spreads indirect pressure.');
        }
    }

// spawns one custos AI from stored data
  function spawnCustos(data: CustosAIData)
    {
      if (game.area == null ||
          game.area.id != areaID)
        return;
      var ai = new ai.CustosAI(game, data.x, data.y, data.custosType);
      ai.updateData(data, 'on custos spawn');
      ai.x = data.x;
      ai.y = data.y;
      ai.guardTargetX = data.anchorX;
      ai.guardTargetY = data.anchorY;
      game.area.addAI(ai);
    }

// returns custos data by ID
  function getCustos(id: Int): CustosAIData
    {
      for (data in custodes)
        if (data.id == id)
          return data;
      return null;
    }

// adds one virtual HUD action
  function action(id: String, name: String, f: Void -> Bool): _PlayerAction
    {
      return {
        id: id,
        type: ACTION_AREA,
        name: name,
        energy: 0,
        isVirtual: true,
        f: function() {
          f();
        }
      };
    }

// returns selected turret direction label
  function directionName(): String
    {
      switch (selectedDirection)
        {
          case 0:
            return 'Direction: north';
          case 1:
            return 'Direction: east';
          case 2:
            return 'Direction: south';
          case 3:
            return 'Direction: west';
          default:
            return 'Direction: north';
        }
    }

// checks blocking objects at a footprint tile
  function hasBlockingObject(x: Int, y: Int,
      type: _CultBaseOrganType): Bool
    {
      for (o in area().getObjectsAt(x, y))
        {
          if (type == RIBGATE && o.type == 'base_organ')
            continue;
          return true;
        }
      return false;
    }

// checks floor walkability without counting objects on the tile
  function isBuildFloorWalkable(x: Int, y: Int): Bool
    {
      var area = area();
      if (x < 0 ||
          y < 0 ||
          x >= area.width ||
          y >= area.height)
        return false;

      var tileID = area.getCellType(x, y);
      var tileset = game.scene.images.getTileset(area.getTilesetTypeID());
      if (tileset == null ||
          !tileset.isWalkable(tileID))
        return false;

      if (area.tiles == null ||
          area.tiles.length == 0)
        area.initTilesFromCells();
      var tile = area.getTiles()[x][y];
      if (tile == null ||
          tile.decoration == null)
        return true;
      for (decoration in tile.decoration)
        if (tileset.isBlockingDecoration(tileID, decoration))
          return false;
      return true;
    }

// removes ribwall record/object for gate replacement
  function removeRibwallAt(x: Int, y: Int)
    {
      var organ = getOrganAt(x, y);
      if (organ == null ||
          organ.type != RIBWALL)
        return;
      organs.remove(organ);
      var area = area();
      var list = [];
      for (o in area.getObjects())
        if (o.type == 'base_organ')
          {
            var obj: BaseOrganObject = cast o;
            if (obj.organID == organ.id)
              list.push(o);
          }
      for (o in list)
        area.removeObject(o);
    }

// returns yes/no text
  function yes(value: Bool): String
    {
      return value ? 'yes' : 'no';
    }
}
