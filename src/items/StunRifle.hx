// defines stun rifle ranged weapon
package items;

import game.Game;

class StunRifle extends Weapon
{
// builds stun rifle weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'stunRifle';
      name = 'stun rifle';
      unknown = 'elongated metallic object';
      weapon = {
        isRanged: true,
        skill: SKILL_RIFLE,
        minDamage: 2,
        maxDamage: 10,
        verb1: 'stun',
        verb2: 'stuns',
        type: WEAPON_STUN,
        sound: {
          file: 'attack-stun-rifle',
          radius: 10,
          alertness: 20,
        },
      };
    }
}
