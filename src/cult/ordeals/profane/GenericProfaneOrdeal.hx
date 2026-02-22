package cult.ordeals.profane;

import game.Game;
import Const.d100;
import cult.effects.*;
import cult.missions.*;
import _OrdealInfo;

class GenericProfaneOrdeal extends ProfaneOrdeal
{
  public var subType: String;
  public var infoID: Int;
  public var info(get, null): _OrdealInfo;
  function get_info(): _OrdealInfo {
    return ProfaneConst.getInfo(subType, infoID);
  }

  public function new(g: Game, ?vsubType: String, ?vinfoID: Int)
    {
      this.subType = vsubType;
      this.infoID = vinfoID;
      
      super(g);
      init();
      initPost(false);
      addRandomMembers({
        level: 1,
        amount: 2
      });

      timer = 8 + Std.random(5);
      // set power requirements using subtype
      var powerval = 0;
      if (cult.countMembers(3) > 1)
        {
          power.money = 100000;
          powerval = 25;
        }
      else if (cult.countMembers(2) > 1)
        {
          power.money = 50000;
          powerval = 10;
        }
      else
        {
          power.money = 20000;
          powerval = 5;
        }
      // random 10% value change
      power.money = Std.int(power.money * (0.9 + (Std.random(21) / 100)));
      // cap to nearest 1000
      power.money = Std.int(power.money / 1000) * 1000;
      // random 10% value change for power
      powerval = Std.int(powerval * (0.9 + (Std.random(21) / 100)));
      power.set(subType, powerval);

      // add random negative effect
      var e: Effect;
      var effectType = Std.random(3); // 0, 1, or 2
      switch (effectType)
        {
          case 0:
            e = new DecreasePower(game, timer, subType);
          case 1:
            e = new DecreaseIncome(game, timer);
          case 2:
            e = new BlockCommunal(game, timer);
          default:
            e = new DecreaseIncome(game, timer); // fallback
        }
      effects.push(e);

      // add mission based on info type
      var m: Mission = null;
      switch (info.mission) {
        case MISSION_PERSUADE:
          m = new Persuade(game, info.target);
        case MISSION_KILL:
          m = new Kill(game, info.target);
        case MISSION_COMBAT:
          if (info.combat == null)
            throw 'Combat mission info not provided for ordeal.';
          switch (info.combat.template)
            {
              case TARGET_WITH_GUARDS:
                m = new CombatTargetsWithGuards(game, info.combat);
              case SUMMONING_RITUAL:
                m = new CombatSummoningRitual(game, info.combat);
              case UNDERGROUND_LAB_PURGE:
                m = new CombatUndergroundLabPurge(game, info.combat);
            }
      }
      missions.push(m);
    }

  // init object before loading/post creation
  public override function init()
    {
      super.init();

      // only pick random subtype if not already set
      if (subType == null)
        subType = ProfaneConst.availableTypes[Std.random(ProfaneConst.availableTypes.length)];
      
      // only pick random ordeal info if not already set
      if (infoID == null)
        {
          // try to find a unique infoID that doesn't conflict with existing ordeals
          var maxAttempts = 100;
          var attempts = 0;
          var ok = false;
          while (attempts < maxAttempts && !ok)
            {
              var candidateID = ProfaneConst.getRandom(subType);
              if (isInfoIDUnique(subType, candidateID))
                {
                  infoID = candidateID;
                  ok = true;
                  break;
                }
              attempts++;
            }

          // if we couldn't find a unique one after max attempts, just use a random one
          if (!ok)
            infoID = ProfaneConst.getRandom(subType);
        }

      name = info.name;
      note = info.note;
    }

// check if the given subtype/infoID is unique
  function isInfoIDUnique(subType: String, infoID: Int): Bool
    {
      // check all active ordeals in the cult
      for (o in cult.ordeals.list)
        {
          if (o == this)
            continue;
          
          if (Reflect.hasField(o, 'subType'))
            {
              var other: GenericProfaneOrdeal = cast o;
              if (other.subType == subType &&
                  other.infoID == infoID)
                return false;
            }
        }
      return true;
    }

  // called on ordeal failure
  override function onFail() {
    game.message({
      title: 'Ordeal Failed',
      titleCol: 'red',
      text: info.fail,
      col: 'cult'
    });
    var turns = d100() < 5 ? 10 : 5;
    cult.addRandomBadEffect(turns);
  }

  // called on ordeal success
  override function onSuccess() {
    game.message({
      title: 'Ordeal Succeeded',
      titleCol: 'white',
      text: info.success,
      col: 'cult'
    });
  }
}
