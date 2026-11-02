// defines full body armor clothing
package items;

import game.Game;
import ItemInfo;

class FullBodyArmor extends ItemInfo
{
// builds full body armor info
  public function new(game: Game)
    {
      super(game);
      id = 'fullBodyArmor';
      name = N('full-body armor');
      type = 'clothing';
      unknown = N('bulky plated garment');
      armor = {
        canAttach: false,
        damage: 8,
        needleDeathChance: 1,
      };
    }
}
