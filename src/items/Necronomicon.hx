// the Necronomicon, the forbidden book on the library archive's lectern (game.LibraryAreaGenerator):
// carried out of the library it completes Metamorphosis Phase I (cult.missions.Necronomicon,
// cult.ordeals.MetamorphosisPhaseI.checkHeld)
package items;

import game.Game;
import game._Item;
import l10n.Loc;
import ItemInfo;
import _PlayerAction;

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
// calls campus security in through the stacks next door to the lectern (AreaManager's backup
// arrival, heading for the cell it was taken from; they despawn once calm)
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
      // they come in through the stacks next door: five cells past the archive's one doorway, so the
      // arrival's radius-5 search cannot land them in the archive itself
      var info = game.area.generatorInfo;
      for (d in info.doors)
        if (info.getRoom(d.roomID1).role == gen.library.LibraryGen.ROLE_ARCHIVE)
          {
            var archive = info.getRoom(d.roomID1);
            game.managerArea.add(AREAEVENT_ARRIVE_BACKUP,
              d.x + (archive.x1 > d.x ? -5 : 5), d.y, 3,
              new game.AreaManager._AreaManagerEventParamsArriveBackup('security',
                game.playerArea.x, game.playerArea.y));
          }
    }

// a read action, which spells out nothing
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      actions.push({
        id: 'read.' + item.id,
        type: ACTION_INVENTORY,
        name: T('Read {item}', { item: Loc.colored('inventory-item', item) }),
        nameClean: T('Read'),
        energy: 10,
        isAgreeable: true,
        item: item
      });
      return actions;
    }

// handles the read action: the host stumbles over the first words and gives up (a turn spent)
  override public function action(actionID: String, action: _PlayerAction): Null<Bool>
    {
      if (actionID != 'read')
        return super.action(actionID, action);
      game.log(T('Klaatu, verata, n... It is unreadable.'));
      return true;
    }
}
