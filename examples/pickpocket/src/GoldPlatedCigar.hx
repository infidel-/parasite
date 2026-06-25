// gold-plated cigar — a concealable luxury item the Burglar King carries. it
// can be smoked once (destroyed after) for a triumphant log line. concealable
// (no weapon/armor info) so the pickpocket filter never skips it.
package;

import game.Game;
import game._Item;

class GoldPlatedCigar extends ItemInfo
{
// builds the cigar info
  public function new(game: Game)
    {
      super(game);
      id = Entry.CIGAR;
      type = 'misc';
      name = 'gold-plated cigar';
      unknown = 'small gilded tube';
    }

// adds the "Smoke" inventory action
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      actions.push({
        id: 'use.' + item.id,
        type: 'ACTION_INVENTORY',
        name: 'Smoke ' + Const.col('inventory-item', item.getName()),
        nameClean: 'Smoke',
        energy: 2,
        item: item,
      });
      return actions;
    }

// handles the smoke action
  override public function action(actionID: String, action: _PlayerAction): Null<Bool>
    {
      return switch (actionID)
        {
          case 'use': smokeAction(action.item);
          default: super.action(actionID, action);
        };
    }

// smokes the cigar once, then destroys it
  function smokeAction(item: _Item): Bool
    {
      var host = game.player.host;
      if (host == null)
        return false;
      host.log('lights the gold-plated cigar and savours it to the last ember. ' +
        'Smoking the Burglar King\'s prized cigar — now <i>that</i> is an achievement.');
      game.scene.sounds.play('item-cigarettes');
      host.inventory.removeItem(item);
      return true;
    }
}
