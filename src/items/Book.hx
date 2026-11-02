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
      unknown = N('object with many markings');
      names = [ N('notebook'), N('diary'), N('journal'), N('logbook'), N('organizer'), N('book') ];
      areaObjectClass = objects.Book;
    }
}
