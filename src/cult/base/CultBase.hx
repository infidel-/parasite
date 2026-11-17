// persistent Cultus Carnis living base state
package cult.base;

import l10n.Loc;
import ai.AI;
import ai.CustosAIData;
import const.CultBaseConst;
import cult.ordeals.BaseDefense;
import game.AreaGame;
import game.Game;
import objects.base.*;

// one turn of organ income and the stored bodies it draws
typedef CultBaseIncome = {
  // resources produced
  var income: CultBaseResources;
  // stored bodies consumed
  var bodies: Int;
}

// the Corpus Basilica requirements and how far the base meets them
typedef CultBaseReadiness = {
  // heart upgrades
  var heart: Int;
  // sum of the levels of every organ but the heart
  var organLevels: Int;
  var hasGrowth: Bool;
  var hasStorage: Bool;
  var hasCauldron: Bool;
  // defense organs
  var defenses: Int;
  // defenses survived
  var survived: Int;
}

class CultBase extends _SaveObject
{
  static var _ignoredFields = [ 'game', 'income', 'cursorX', 'cursorY', 'selectedType', 'selectedDirection' ];
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
      game.logsg(T('Cor Nefandum begins to pulse with eldritch energy.'));
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
      var res = incomePerTurn();
      income = res.income;
      storedBodies -= res.bodies;
      resources.add(income, stockpileCap());

      // heal custodes between attacks
      healCustodes();

      // increase pressure
      addPressure(1 + getHeartUpgradeCount());

      // run rival turns
      runRivalTurn();
      if (!income.isEmpty())
        game.logsg(T('Base income: {income}.', { income: income.text() }));
    }

// returns one turn of organ income and the stored bodies it draws, mutating nothing
  public function incomePerTurn(): CultBaseIncome
    {
      var ret = {
        income: new CultBaseResources(),
        bodies: 0,
      };
      var bodies = storedBodies;
      for (organ in organs)
        {
          if (!organ.isWorking())
            continue;
          switch (organ.type)
            {
              case FLESH_BLOCK:
                ret.income.flesh += 5 * organ.level;
              case RAT_NEST:
                ret.income.flesh += 3 * organ.level;
                ret.income.blood += organ.level;
                ret.income.bone += organ.level;
              case CRUSHER:
                if (bodies > 0)
                  {
                    bodies--;
                    ret.income.bone += 5 * organ.level;
                  }
              case GARBAGE_HEAP:
                if (bodies > 0)
                  {
                    bodies--;
                    ret.income.flesh += 5 * organ.level;
                  }
                else ret.income.flesh += 2 * organ.level;
              default:
            }
        }
      ret.bodies = storedBodies - bodies;
      return ret;
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
        text: T('Heretics close on Cor Nefandum. Defend the base before the timer expires.'),
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
          game.actionFailed(T('Not enough base resources.'));
          return false;
        }
      resources.spend(cost);
      // a turret faces one of four ways, a wall runs one of two, a gate keeps its wall's
      var direction = selectedDirection;
      if (type == RIBWALL)
        direction = selectedDirection % 2;
      else if (type == RIBGATE)
        direction = removeRibwallAt(cursorX, cursorY);
      var organ = new CultBaseOrgan(type, areaID, cursorX, cursorY,
        direction);
      organs.push(organ);
      createOrganObject(organ);
      game.log(T('You shape {organ}.', { organ: Loc.tr(CultBaseConst.name(type)) }));
      game.updateHUD();
      return true;
    }

// upgrades organ at cursor when possible
  public function upgradeAtCursor(): Bool
    {
      var organ = getOrganAt(cursorX, cursorY);
      if (organ == null)
        {
          game.actionFailed(T('No base organ at cursor.'));
          return false;
        }
      var reason = validateUpgrade(organ);
      if (reason != '')
        {
          game.actionFailed(reason);
          return false;
        }
      var cost = organ.upgradeCost();
      resources.spend(cost);
      organ.level++;
      organ.broken = false;
      organ.health = organ.maxHealth();
      refreshOrganObject(organ);
      game.log(T('You strengthen {organ}.', { organ: Loc.tr(CultBaseConst.name(organ.type)) }));
      game.updateHUD();
      return true;
    }

// returns why the organ cannot be upgraded, or '' when it can
  public function validateUpgrade(organ: CultBaseOrgan): String
    {
      if (organ.level >= CultBaseConst.info(organ.type).maxLevel)
        return T('This organ cannot grow further.');
      if (!resources.canAfford(organ.upgradeCost()))
        return T('Not enough base resources.');
      return '';
    }

// returns why the organ cannot be repaired, or '' when it can
  public function validateRepair(organ: CultBaseOrgan): String
    {
      if (organ.health >= organ.maxHealth() &&
          !organ.broken)
        return T('This organ is whole.');
      if (!resources.canAfford(organ.repairCost()))
        return T('Not enough base resources.');
      return '';
    }

// returns why a custos cannot be created at the tile, or '' when it can
  public function validateCustos(x: Int, y: Int): String
    {
      if (!hasWorkingOrgan(CAULDRON))
        return T('A working Caldarium is required.');
      if (custodes.length >= custosCap())
        return T('Custodes capacity reached.');
      if (!resources.canAfford(CultBaseConst.custosCost))
        return T('Not enough base resources.');
      if (!area().isWalkable(x, y) ||
          area().hasAI(x, y))
        return T('Custos needs a free tile.');
      return '';
    }

// repairs organ at cursor when possible
  public function repairAtCursor(): Bool
    {
      var organ = getOrganAt(cursorX, cursorY);
      if (organ == null)
        {
          game.actionFailed(T('No base organ at cursor.'));
          return false;
        }
      var reason = validateRepair(organ);
      if (reason != '')
        {
          game.actionFailed(reason);
          return false;
        }
      var cost = organ.repairCost();
      resources.spend(cost);
      organ.health = organ.maxHealth();
      organ.broken = false;
      refreshOrganObject(organ);
      game.log(T('You mend {organ}.', { organ: Loc.tr(CultBaseConst.name(organ.type)) }));
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
            game.log(Const.col('alert', T('Cor Nefandum is wounded!')));
          refreshOrganObject(organ);
          return;
        }
      organ.health = 0;
      if (organ.type == COR_NEFANDUM)
        {
          game.finish({
            result: 'lose',
            text: 'corNefandum',
            img: 'event/death',
            filter: 'cult'
          });
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
  public function createCustos(type: String): Bool
    {
      var reason = validateCustos(cursorX, cursorY);
      if (reason != '')
        {
          game.actionFailed(reason);
          return false;
        }
      resources.spend(CultBaseConst.custosCost);
      var ai = game.createAI(type, cursorX, cursorY);
      ai.guardTargetX = cursorX;
      ai.guardTargetY = cursorY;
      var data = new CustosAIData(game);
      data.updateFromAI(ai, areaID, cursorX, cursorY,
        'on custos creation');
      custodes.push(data);
      game.area.addAI(ai);
      game.log(T('A new Custos takes shape.'));
      game.updateHUD();
      game.scene.draw();
      return true;
    }

// records custos data when it leaves or dies
  public function onRemoveAI(ai: AI)
    {
      var data = getCustos(ai.id);
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
            var data = getCustos(ai.id);
            if (data != null)
              {
                data.updateFromAI(ai, areaID, data.anchorX, data.anchorY,
                  'on custos despawn');
              }
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

// returns base status text for cult window
  public function statusText(): String
    {
      return T('Level 2 base at area {area}', { area: areaID }) +
        '<br/>' + T('Flesh {flesh}, Blood {blood}, Bone {bone} / {cap}', {
          flesh: resources.flesh,
          blood: resources.blood,
          bone: resources.bone,
          cap: stockpileCap(),
        }) +
        '<br/>' + T('Bodies {bodies}/{capacity}, Custodes {custodes}/{custosCap}, Pressure {pressure}', {
          bodies: storedBodies,
          capacity: bodyCapacity(),
          custodes: custodes.length,
          custosCap: custosCap(),
          pressure: attackPressure,
        }) +
        (activeDefenseMissionID >= 0 ?
          '<br/>' + Const.col('alert', T('Base defense timer: {timer}', { timer: activeDefenseTimer })) :
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
        return T('Cor Nefandum already exists.');
      if (type == RIBGATE)
        {
          var existing = getOrganAt(x, y);
          if (existing == null ||
              existing.type != RIBWALL)
            return T('Porta Costarum must replace a ribwall.');
        }
      else if (getOrganAt(x, y) != null)
        return T('Tile already holds a base organ.');

      var area = area();
      var fp = CultBaseConst.footprint(type, x, y);
      for (pt in fp)
        {
          if (!isBuildFloorWalkable(pt.x, pt.y))
            return T('Footprint must be on walkable floor.');
          if (area.hasAI(pt.x, pt.y))
            return T('Footprint is occupied.');
          if (hasBlockingObject(pt.x, pt.y, type))
            return T('Footprint is blocked.');
        }
      return '';
    }

// returns Corpus Basilica readiness numbers
  public function readiness(): CultBaseReadiness
    {
      var ret = {
        heart: getHeartUpgradeCount(),
        organLevels: 0,
        hasGrowth: false,
        hasStorage: false,
        hasCauldron: false,
        defenses: 0,
        survived: defensesSurvived,
      };
      for (organ in organs)
        {
          if (organ.type == COR_NEFANDUM)
            continue;
          ret.organLevels += organ.level;
          var info = CultBaseConst.info(organ.type);
          if (info.isGrowth)
            ret.hasGrowth = true;
          if (organ.type == BODY_STORAGE)
            ret.hasStorage = true;
          if (organ.type == CAULDRON)
            ret.hasCauldron = true;
          if (info.isDefense)
            ret.defenses++;
        }
      return ret;
    }

// returns Corpus Basilica readiness summary
  public function readinessText(): String
    {
      var r = readiness();
      return Const.smallgray(T('Corpus Basilica: Heart {heart}/3, organs {organs}/10<br/>' +
        'Growth {growth}, storage {storage}, cauldron {cauldron}<br/>' +
        'Defenses {defenses}/5, survived {survived}/2', {
        heart: r.heart,
        organs: r.organLevels,
        growth: yes(r.hasGrowth),
        storage: yes(r.hasStorage),
        cauldron: yes(r.hasCauldron),
        defenses: r.defenses,
        survived: r.survived,
      }));
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
  public function bodyCapacity(): Int
    {
      var cap = 0;
      for (organ in organs)
        if (organ.type == BODY_STORAGE &&
            organ.isWorking())
          cap += 8 * organ.level;
      return cap;
    }

// returns total custodes capacity
  public function custosCap(): Int
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
          game.logsg(T('{cult} drives heathens toward the base.', { cult: Loc.tr(rival.name) }));
        }
      else
        {
          addPressure(5, rival.id);
          game.logsg(T('{cult} spreads indirect pressure.', { cult: Loc.tr(rival.name) }));
        }
    }

// spawns one custos AI from stored data
  function spawnCustos(data: CustosAIData)
    {
      if (game.area == null ||
          game.area.id != areaID)
        return;
      var ai = game.createAI(data.type, data.x, data.y);
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
      return (tileset != null &&
        tileset.isWalkable(tileID));
    }

// removes ribwall record/object for gate replacement and returns the wall's direction
  function removeRibwallAt(x: Int, y: Int): Int
    {
      var organ = getOrganAt(x, y);
      if (organ == null ||
          organ.type != RIBWALL)
        return 0;
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
      return organ.direction;
    }

// returns yes/no text
  function yes(value: Bool): String
    {
      return value ? T('yes') : T('no');
    }
}
