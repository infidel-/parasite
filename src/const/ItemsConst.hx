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
  public static var fists: _ItemInfo = {
    id: 'fists',
    name: 'fists',
    type: 'weapon',
    unknown: 'fists',
    weapon: {
      isRanged: false,
      skill: SKILL_FISTS,
      minDamage: 1,
      maxDamage: 3,
      verb1: 'punch',
      verb2: 'punches',
      type: WEAPON_BLUNT,
      sound: 'attack-fists',
    }
  };

// special item: animal attack
  public static var animal: _ItemInfo = {
    id: 'animal',
    name: 'animal BUG!!!',
    type: 'weapon',
    unknown: 'animal BUG!!!',
    weapon: {
      isRanged: false,
      skill: SKILL_ATTACK,
      minDamage: 1,
      maxDamage: 4,
      verb1: 'attack',
      verb2: 'attacks',
      // don't bother with weapon type
      type: WEAPON_BLUNT,
      sound: 'attack-bite',
    }
  };

// special item: no armor
  public static var armorNone: _ItemInfo = {
    id: 'armorNone',
    name: 'no armor',
    type: 'clothing',
    unknown: 'clothing',
    armor: {
      canAttach: true,
      damage: 0,
      needleDeathChance: 10,
    }
  };

// all item infos
  public static var items: Array<_ItemInfo> = [
    // ========= ******* weapons ********* ==========
    {
      id: 'baton',
      name: 'baton',
      type: 'weapon',
      unknown: 'elongated object',
      weapon: {
        isRanged: false,
        skill: SKILL_BATON,
        minDamage: 1,
        maxDamage: 6,
        verb1: 'hit',
        verb2: 'hits',
        type: WEAPON_BLUNT,
        sound: 'attack-baton',
      }
    },
    {
      id: 'stunner',
      name: 'stunner',
      type: 'weapon',
      unknown: 'elongated object',
      weapon: {
        isRanged: false,
        skill: SKILL_FISTS,
        minDamage: 2, // rounds of stun effect instead of damage
        maxDamage: 8,
        verb1: 'stun',
        verb2: 'stuns',
        type: WEAPON_STUN,
        sound: 'attack-stunner',
      }
    },
    {
      id: 'pistol',
      name: 'pistol',
      type: 'weapon',
      unknown: 'metallic object',
      weapon: {
        isRanged: true,
        skill: SKILL_PISTOL,
        minDamage: 1,
        maxDamage: 10,
        verb1: 'shoot',
        verb2: 'shoots',
        type: WEAPON_KINETIC,
        sound: 'attack-pistol',
      }
    },
    {
      id: 'assaultRifle',
      name: 'assault rifle',
      type: 'weapon',
      unknown: 'elongated metallic object',
      weapon: {
        isRanged: true,
        skill: SKILL_RIFLE,
        minDamage: 2,
        maxDamage: 12,
        verb1: 'shoot',
        verb2: 'shoots',
        type: WEAPON_KINETIC,
        sound: 'attack-assault-rifle',
      }
    },
    {
      id: 'combatShotgun',
      name: 'combat shotgun',
      type: 'weapon',
      unknown: 'elongated metallic object',
      weapon: {
        isRanged: true,
        skill: SKILL_SHOTGUN,
        minDamage: 4,
        maxDamage: 24,
        verb1: 'shoot',
        verb2: 'shoots',
        type: WEAPON_KINETIC,
        sound: 'attack-shotgun',
      }
    },
    {
      id: 'stunRifle',
      name: 'stun rifle',
      type: 'weapon',
      unknown: 'elongated metallic object',
      weapon: {
        isRanged: true,
        skill: SKILL_RIFLE,
        minDamage: 2, // rounds of stun effect instead of damage
        maxDamage: 10,
        verb1: 'stun',
        verb2: 'stuns',
        type: WEAPON_STUN,
        sound: 'attack-stun-rifle',
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
        needleDeathChance: 5,
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
        needleDeathChance: 1,
      }
    },

    // ========= ******* readables ********* ==========
    {
      id: 'paper',
      names: [ 'piece of paper', 'report', 'document', 'note', 'dossier',
        'sheet of paper', 'page', 'analysis' ],
      type: 'readable',
      unknown: 'thin object with markings',
      areaObjectClass: Paper,
    },

    {
      id: 'book',
      names: [ 'notebook', 'diary', 'journal', 'logbook', 'organizer', 'book' ],
      type: 'readable',
      unknown: 'object with many markings',
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
      id: 'radio',
      name: 'police radio',
      type: 'radio',
      unknown: 'small plastic object',
    },
    {
      id: 'money',
      name: 'wad of money',
      type: 'junk',
      unknown: 'pack of thin objects',
    },
    {
      id: 'wallet',
      name: 'wallet',
      type: 'junk',
      unknown: 'small leather object',
    },
    {
      id: 'cigarettes',
      name: 'pack of cigarettes',
      type: 'junk',
      unknown: 'small container',
    },
    {
      id: 'nutrients',
      name: 'nutrients',
      type: 'nutrients',
      unknown: 'uneven dark-red object',
      isKnown: true,
    },
    {
      id: 'sleepingPills',
      name: 'bottle of sleeping pills',
      type: 'junk',
      unknown: 'small plastic container',
      // maybe later make something like "completeGoalOnLearn" if needed
      onLearn: function (game, player)
        {
          // path 1: on learn pills after creating habitat
          // path 2: on creating habitat with pills learned
          if (game.goals.completed(GOAL_CREATE_HABITAT))
            {
              game.goals.receive(GOAL_LEARN_PRESERVATOR, SILENT_SYSTEM);
              game.goals.complete(GOAL_LEARN_PRESERVATOR, SILENT_SYSTEM);
            }
        }
    },
  ];
}
