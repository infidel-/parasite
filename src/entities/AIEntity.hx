// AI engine entity

package entities;

import ai.AI;
import game.Game;

class AIEntity extends PawnEntity
{
  public var ai: AI; // AI link
  public var isMissionTarget: Bool;


  public function new(vai: AI, g: Game, xx: Int, yy: Int)
    {
      super(g, xx, yy);

      isMissionTarget = false;
      ai = vai;
    }

// set mission target flag
  public inline function setMissionTarget()
    {
      isMissionTarget = true;
    }
}
