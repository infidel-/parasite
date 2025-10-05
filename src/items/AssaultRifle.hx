// defines assault rifle ranged weapon
package items;

import game.Game;
import ItemInfo;

class AssaultRifle extends ItemInfo
{
// builds assault rifle weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'assaultRifle';
      name = 'assault rifle';
      type = 'weapon';
      unknown = 'elongated metallic object';
      weapon = {
        isRanged: true,
        skill: SKILL_RIFLE,
        minDamage: 2,
        maxDamage: 12,
        verb1: 'shoot',
        verb2: 'shoots',
        type: WEAPON_KINETIC,
        sound: {
          file: 'attack-assault-rifle',
          radius: 15,
          alertness: 40,
        },
      };
    }
}
