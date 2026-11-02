// defines group dossier readable item: intel on the group, read in a habitat
package items;

import l10n.Loc;

import game.Game;
import game._Item;

class Dossier extends Readable
{
// builds dossier readable info
  public function new(game: Game)
    {
      super(game);
      id = 'dossier';
      // own type: a 'readable' lying around counts as a timeline clue in AreaGame
      type = 'dossier';
      unknown = N('thin folder with markings');
      name = N('dossier');
      areaObjectClass = objects.Paper;
    }

// reads the dossier for group intel (no timeline needed, works in sandbox)
  override function readAction(item: _Item): Bool
    {
      if (game.player.host.hasTrait(TRAIT_ILLITERATE))
        {
          itemFailed(T("This host cannot read."));
          return false;
        }
      if (!game.area.isHabitat)
        {
          itemFailed(T("This action requires intense concentration and time. You can only do it in a habitat."));
          game.profile.addPediaArticle('msgConcentration');
          return false;
        }

      game.log(T('You study the contents of {item:the} and destroy it.', { item: Loc.thing(item.name) }));
      game.group.addIntel(3);
      game.scene.sounds.play('item-paper');
      game.player.host.inventory.removeItem(item);
      return true;
    }
}
