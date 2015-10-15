// item list

package const;

import game.ItemInfo;
import objects.*;

class ItemsConst
{
// return item info by id
  public static function getInfo(id: String): ItemInfo
    {
      for (ii in items)
        if (ii.id == id)
          return ii;

      throw 'No such item: ' + id;
      return null;
    }


// special item: fists
  public static var fists: ItemInfo = 
    {
      id: 'fists',
      name: 'fists',
      type: 'weapon',
      unknown: 'fists',
      verb1: 'punch',
      verb2: 'punches',
      weaponStats:
        {
          isRanged: false,
          skill: SKILL_FISTS,
          minDamage: 1,
          maxDamage: 3
        }
    };


// all item infos
  public static var items: Array<ItemInfo> = [
    // ========= ******* weapons ********* ==========
    {
      id: 'baton',
      name: 'baton',
      type: 'weapon',
      unknown: 'hard elongated object',
      verb1: 'hit',
      verb2: 'hits',
      weaponStats:
        {
          isRanged: false,
          skill: SKILL_BATON,
          minDamage: 1,
          maxDamage: 6
        }
    },
    {
      id: 'pistol',
      name: 'pistol',
      type: 'weapon',
      unknown: 'metallic object with a handle',
      verb1: 'shoot',
      verb2: 'shoots',
      weaponStats:
        {
          isRanged: true,
          skill: SKILL_PISTOL,
          minDamage: 1,
          maxDamage: 10
        }
    },
    {
      id: 'assaultRifle',
      name: 'assault rifle',
      type: 'weapon',
      unknown: 'elongated metallic object with a handle',
      verb1: 'shoot',
      verb2: 'shoots',
      weaponStats:
        {
          isRanged: true,
          skill: SKILL_RIFLE,
          minDamage: 2,
          maxDamage: 12
        }
    },
    {
      id: 'combatShotgun',
      name: 'combat shotgun',
      type: 'weapon',
      unknown: 'elongated metallic object with a handle',
      verb1: 'shoot',
      verb2: 'shoots',
      weaponStats:
        {
          isRanged: true,
          skill: SKILL_SHOTGUN,
          minDamage: 4,
          maxDamage: 24
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
      type: 'money',
      unknown: 'a pack of soft thin objects',
    },
    {
      id: 'cigarettes',
      name: 'cigarettes',
      type: 'cigarettes',
      unknown: 'small container full of thin cylinders',
    },
    ];
}
