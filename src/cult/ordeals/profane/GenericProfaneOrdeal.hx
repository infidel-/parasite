package cult.ordeals.profane;

import game.Game;
import Const.d100;
import cult.ProfaneOrdeal;
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

  public function new(g: Game, ?subType: String, ?infoID: Int)
    {
      this.subType = subType;
      this.infoID = infoID;
      
      super(g);
      init();
      initPost(false);
      addRandomMembers({
        level: 1,
        amount: 2
      });
    }

  // init object before loading/post creation
  public override function init()
    {
      super.init();

      // only pick random subtype if not already set
      if (subType == null)
        {
          subType = ProfaneConst.availableTypes[Std.random(ProfaneConst.availableTypes.length)];
        }
      // only pick random ordeal info if not already set
      if (infoID == null)
        infoID = ProfaneConst.getRandom(subType);

      name = info.name;
      note = info.note;
      timer = 10;

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
      }
      missions.push(m);

      // set power requirements using subtype
      power.set(subType, 15);
      power.money = 50000;
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
