// defines book readable item
package items;

import game.Game;

class Book extends Readable
{
// builds book readable info
  public function new(game: Game)
    {
      super(game);
      id = 'book';
      unknown = 'object with many markings';
      names = [ 'notebook', 'diary', 'journal', 'logbook', 'organizer', 'book' ];
      areaObjectClass = objects.Book;
    }
}
