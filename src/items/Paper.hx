// defines paper readable item
package items;

import game.Game;
import ItemInfo;

class Paper extends ItemInfo
{
// builds paper readable info
  public function new(game: Game)
    {
      super(game);
      id = 'paper';
      type = 'readable';
      unknown = 'thin object with markings';
      names = [
        'piece of paper',
        'report',
        'document',
        'note',
        'dossier',
        'sheet of paper',
        'page',
        'analysis',
        'receipt',
        'article'
      ];
      areaObjectClass = objects.Paper;
    }
}
