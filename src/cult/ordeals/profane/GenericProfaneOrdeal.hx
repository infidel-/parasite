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
      var info: _OrdealInfo = ProfaneConst.getInfo(subType, infoID);

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
          m = new Persuade(game);
        case MISSION_KILL:
          m = new Kill(game);
      }
      missions.push(m);

      // set power requirements using subtype
      power.set(subType, 15);
      power.money = 50000;
    }

  // get info property based on subtype
  function get_info(): _OrdealInfo {
    return ProfaneConst.getInfo(subType, infoID);
  }

  // called on ordeal failure
  override function onFail() {
    var turns = d100() < 5 ? 10 : 5;
    var eff = new LoseResource(game, turns, 'lawfare');
    cult.effects.add(eff);
    game.message(info.fail, null, COLOR_CULT);
  }

  // called on ordeal success
  override function onSuccess() {
    game.message(info.success, null, COLOR_CULT);
  }

  // called after load or creation
  public override function initPost(onLoad: Bool) {
    super.initPost(onLoad);
  }
}
