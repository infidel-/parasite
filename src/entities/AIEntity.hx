// AI engine entity

package entities;

import ai.AI;
import game.Game;

class AIEntity extends PawnEntity
{
  public var ai: AI; // AI link


  public function new(vai: AI, g: Game, xx: Int, yy: Int)
    {
      super(g, xx, yy);

      ai = vai;
    }
}
