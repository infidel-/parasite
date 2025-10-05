// defines smartphone item
package items;

import game.Game;

class Smartphone extends Computer
{
// builds smartphone info
  public function new(game: Game)
    {
      super(game);
      id = 'smartphone';
      name = 'smartphone';
      unknown = 'small plastic object';
    }
}
