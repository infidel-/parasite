// combat mission target info

import game.Game;
import ai.AIData;

typedef _CombatMissionTargetInfo = {
  var target: _MissionTarget;
  var amount: Array<Int>; // target count by difficulty [easy, normal, hard]
  var loadout: Game -> AIData -> _Difficulty -> Void;
}
