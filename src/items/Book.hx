// defines book readable item
package items;

import game.Game;
import ItemInfo;

class Book extends ItemInfo
{
// builds book readable info
  public function new(game: Game)
    {
      super(game);
      id = 'book';
      type = 'readable';
      unknown = 'object with many markings';
      names = [ 'notebook', 'diary', 'journal', 'logbook', 'organizer', 'book' ];
      areaObjectClass = objects.Book;
    }
}
