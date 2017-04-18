// item list

package const;

import game._ItemInfo;
import objects.*;

class ItemsConst
{
// return item info by id
  public static function getInfo(id: String): _ItemInfo
    {
      for (ii in items)
        if (ii.id == id)
          return ii;

      throw 'No such item: ' + id;
      return null;
    }


// special item: fists
  public static var fists: _ItemInfo =
    {
      id: 'fists',
      name: 'fists',
      type: 'weapon',
      unknown: 'fists',
      weapon:
        {
          isRanged: false,
          skill: SKILL_FISTS,
          minDamage: 1,
          maxDamage: 3,
          verb1: 'punch',
          verb2: 'punches',
          type: WEAPON_BLUNT,
        }
    };


// special item: animal attack
  public static var animal: _ItemInfo =
    {
      id: 'animal',
      name: 'animal BUG!!!',
      type: 'weapon',
      unknown: 'animal BUG!!!',
      weapon:
        {
          isRanged: false,
          skill: SKILL_ATTACK,
          minDamage: 1,
          maxDamage: 4,
          verb1: 'attack',
          verb2: 'attacks',
          // don't bother with weapon type
          type: WEAPON_BLUNT,
        }
    };


// special item: no armor
  public static var armorNone: _ItemInfo =
    {
      id: 'armorNone',
      name: 'no armor',
      type: 'clothing',
      unknown: 'clothing',
      armor: {
        canAttach: true,
        damage: 0,
      }
    };


// all item infos
  public static var items: Array<_ItemInfo> = [
    // ========= ******* weapons ********* ==========
    {
      id: 'baton',
      name: 'baton',
      type: 'weapon',
      unknown: 'hard elongated object',
      weapon:
        {
          isRanged: false,
          skill: SKILL_BATON,
          minDamage: 1,
          maxDamage: 6,
          verb1: 'hit',
          verb2: 'hits',
          type: WEAPON_BLUNT,
        }
    },
    {
      id: 'stunner',
      name: 'stunner',
      type: 'weapon',
      unknown: 'hard elongated object',
      weapon:
        {
          isRanged: false,
          skill: SKILL_FISTS,
          minDamage: 2, // rounds of stun effect instead of damage
          maxDamage: 8,
          verb1: 'stun',
          verb2: 'stuns',
          type: WEAPON_STUN,
        }
    },
    {
      id: 'pistol',
      name: 'pistol',
      type: 'weapon',
      unknown: 'metallic object with a handle',
      weapon:
        {
          isRanged: true,
          skill: SKILL_PISTOL,
          minDamage: 1,
          maxDamage: 10,
          verb1: 'shoot',
          verb2: 'shoots',
          type: WEAPON_KINETIC,
        }
    },
    {
      id: 'assaultRifle',
      name: 'assault rifle',
      type: 'weapon',
      unknown: 'elongated metallic object with a handle',
      weapon:
        {
          isRanged: true,
          skill: SKILL_RIFLE,
          minDamage: 2,
          maxDamage: 12,
          verb1: 'shoot',
          verb2: 'shoots',
          type: WEAPON_KINETIC,
        }
    },
    {
      id: 'combatShotgun',
      name: 'combat shotgun',
      type: 'weapon',
      unknown: 'elongated metallic object with a handle',
      weapon:
        {
          isRanged: true,
          skill: SKILL_SHOTGUN,
          minDamage: 4,
          maxDamage: 24,
          verb1: 'shoot',
          verb2: 'shoots',
          type: WEAPON_KINETIC,
        }
    },
    {
      id: 'stunRifle',
      name: 'stun rifle',
      type: 'weapon',
      unknown: 'elongated metallic object with a handle',
      weapon:
        {
          isRanged: true,
          skill: SKILL_RIFLE,
          minDamage: 2, // rounds of stun effect instead of damage
          maxDamage: 10,
          verb1: 'stun',
          verb2: 'stuns',
          type: WEAPON_STUN,
        }
    },

    // ========= ******* clothing ********* ==========

    {
      id: 'kevlarArmor',
      name: 'kevlar armor',
      type: 'clothing',
      unknown: 'ARMOR BUG!',
      armor: {
        canAttach: true,
        damage: 2,
      }
    },

    {
      id: 'fullBodyArmor',
      name: 'full-body armor',
      type: 'clothing',
      unknown: 'ARMOR BUG!',
      armor: {
        canAttach: false,
        damage: 4,
      }
    },

    // ========= ******* readables ********* ==========
    {
      id: 'paper',
      names: [ 'piece of paper', 'report', 'document', 'note', 'dossier',
        'sheet of paper', 'page' ],
      type: 'readable',
      unknown: 'rectangular thin object with markings',
      areaObjectClass: Paper,
    },

    {
      id: 'book',
      names: [ 'notebook', 'diary', 'journal', 'logbook', 'organizer', 'book' ],
      type: 'readable',
      unknown: 'rectangular object with lots of markings',
      areaObjectClass: Book,
    },


    // ========= ******* misc ********* ==========
    {
      id: 'mobilePhone',
      name: 'mobile phone',
      type: 'phone',
      unknown: 'small plastic object',
    },
    {
      id: 'smartphone',
      name: 'smartphone',
      type: 'computer',
      unknown: 'small plastic object',
    },
    {
      id: 'laptop',
      name: 'laptop',
      type: 'computer',
      unknown: 'rectangular plastic object',
    },
    {
      id: 'money',
      name: 'money',
      type: 'junk',
      unknown: 'a pack of soft thin objects',
    },
    {
      id: 'wallet',
      name: 'wallet',
      type: 'junk',
      unknown: 'small leather object',
    },
    {
      id: 'cigarettes',
      name: 'cigarettes',
      type: 'junk',
      unknown: 'small container full of thin cylinders',
    },
    ];
}
