// defines laptop item
package items;

import game.Game;

class Laptop extends Computer
{
// builds laptop info
  public function new(game: Game)
    {
      super(game);
      id = 'laptop';
      name = 'laptop';
      unknown = 'plastic rectangular object';
    }
}
