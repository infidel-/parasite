// defines paper readable item
package items;

import game.Game;

class Paper extends Readable
{
// builds paper readable info
  public function new(game: Game)
    {
      super(game);
      id = 'paper';
      unknown = N('thin object with markings');
      names = [
        N('piece of paper'),
        N('report'),
        N('document'),
        N('note'),
        N('dossier'),
        N('sheet of paper'),
        N('page'),
        N('analysis'),
        N('receipt'),
        N('article')
      ];
      areaObjectClass = objects.Paper;
    }
}
