// the Necronomicon, the forbidden book on the library archive's lectern (game.LibraryAreaGenerator):
// carried out of the library it completes Metamorphosis Phase I (cult.missions.Necronomicon,
// cult.ordeals.MetamorphosisPhaseI.checkHeld)
package items;

import game.Game;
import game._Item;
import ItemInfo;

class Necronomicon extends ItemInfo
{
  public function new(game: Game)
    {
      super(game);
      id = 'necronomicon';
      // a scenario item outlives the player leaving the area it lies in (game.AreaGame.addItem)
      type = 'scenario';
      name = N('Necronomicon');
      unknown = N('ancient book');
      isKnown = true;
      names = [ N('Necronomicon') ];
    }

// taking it raises the floor: the librarian and every guard on it turn on the thief, and the bell
// calls campus security up the stairs (AreaManager's backup arrival, which despawns them once calm)
  public override function onPickup(item: _Item)
    {
      if (game.area.typeID != AREA_LIBRARY)
        return;
      game.log(T('A shrill bell rings through the stacks as the book leaves the lectern.'),
        COLOR_ALERT);
      game.scene.sounds.play('library/bell');
      for (ai in game.area.getAllAI())
        if (ai.state != AI_STATE_DEAD &&
            ai != game.player.host &&
            (ai.type == 'librarian' ||
             ai.type == 'security'))
          ai.setState(AI_STATE_ALERT, REASON_WITNESS);
      for (o in game.area.getObjects())
        if (Std.isOfType(o, objects.Stairs))
          game.managerArea.add(AREAEVENT_ARRIVE_BACKUP, o.x, o.y, 3,
            new game.AreaManager._AreaManagerEventParamsArriveBackup('security'));
    }
}
