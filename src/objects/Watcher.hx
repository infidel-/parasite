// habitat - watcher

package objects;

import game.Game;

class Watcher extends HabitatObject
{
  public function new(g: Game, vx: Int, vy: Int, l: Int)
    {
      super(g, vx, vy, l);

      name = 'watcher';
      spawnMessage = 'The watcher blinks its eyes and joins you.';

      createEntity(game.scene.entityAtlas[level][Const.ROW_WATCHER]);
    }
}

