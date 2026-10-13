// defines kevlar armor clothing
package items;

import game.Game;
import ItemInfo;

class KevlarArmor extends ItemInfo
{
// builds kevlar armor info
  public function new(game: Game)
    {
      super(game);
      id = 'kevlarArmor';
      name = 'kevlar armor';
      type = 'clothing';
      unknown = 'padded garment';
      armor = {
        canAttach: true,
        damage: 4,
        needleDeathChance: 5,
      };
    }
}
