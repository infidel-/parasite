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

  public function new(g: Game)
    {
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

      // pick random subtype
      static var availableSubTypes = ['media'];
      subType = availableSubTypes[Std.random(availableSubTypes.length)];

      // pick random ordeal info based on subtype
      infoID = ProfaneConst.getRandom(subType);

      name = info.name;
      note = info.note;
      timer = 10;

      // add negative effect
      var effect = new DecreaseIncome(game, timer);
      effects.push(effect);

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
    var turns = d100() < 5 ? 10 : 5;
    var eff = new LoseResource(game, turns, 'lawfare');
    cult.effects.add(eff);
    game.message({
      title: 'Ordeal Failed',
      titleCol: 'red',
      text: info.fail,
      col: 'cult'
    });
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
