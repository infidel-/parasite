// the librarian's elder sign (ai.LibrarianAI): burns the parasite while its keeper lives, and cannot
// be taken from the body
package items;

import game.Game;
import ItemInfo;

class ElderSign extends ItemInfo
{
  public function new(game: Game)
    {
      super(game);
      id = 'elderSign';
      type = 'special';
      name = N('elder sign');
      unknown = N('strange amulet');
      isKnown = true;
      names = [ N('elder sign') ];
    }
}
