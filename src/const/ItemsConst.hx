// item list

package const;

import game.Game;
import game._ItemInfo;
import game._Item;
import objects.*;

class ItemsConst
{
// spawn item by id
  public static function spawnItem(game: Game, id: String): _Item
    {
      var info = getInfo(id);
      if (info == null)
        {
          trace('No such item id: ' + id);
          return null;
        }
      var name = info.name;
      if (info.names != null) // pick a name
        name = info.names[Std.random(info.names.length)];
      var item: _Item = {
        game: game,
        id: id,
        info: info,
        name: name,
        event: null,
      };
      return item;
    }

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
      sound: {
        file: 'attack-fists',
        radius: 5,
        alertness: 5,
      },
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
      sound: {
        file: 'attack-bite',
        radius: 5,
        alertness: 3,
      },
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
        sound: {
          file: 'attack-baton',
          radius: 5,
          alertness: 10,
        },
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
        sound: {
          file: 'attack-stunner',
          radius: 3,
          alertness: 10,
        },
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
        sound: {
          file: 'attack-pistol',
          radius: 15,
          alertness: 30,
        },
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
        sound: {
          file: 'attack-assault-rifle',
          radius: 15,
          alertness: 40,
        },
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
        sound: {
          file: 'attack-shotgun',
          radius: 10,
          alertness: 30,
        },
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
        sound: {
          file: 'attack-stun-rifle',
          radius: 10,
          alertness: 20,
        },
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
      names: [
        'piece of paper', 'report', 'document',
        'note', 'dossier', 'sheet of paper',
        'page', 'analysis', 'receipt', 'article',
      ],
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
      unknown: 'plastic rectangular object',
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
      updateActionList: function(game: Game, item: _Item) {
        if (game.player.knowsItem(item.id))
          game.ui.hud.addAction({
            id: 'throwMoney.' + item.id,
            type: ACTION_INVENTORY,
            item: item,
            name: 'Throw money',
            energy: 5,
            isAgreeable: true,
          });
      }
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
    {
      id: 'contraceptives',
      name: 'pack of contraceptives',
      type: 'junk',
      unknown: 'small container',
      onLearn: function (game, player)
        {
          game.message('Humans use these to control their breeding habits. However, there is a way that I can reproduce as well.', 'event/goal_evolve_dopamine_receive');
          player.evolutionManager.addImprov(IMP_OVUM);
          game.profile.addPediaArticle('impOvum');
        }
    },

    // ============================================
    // scenario-related items
    {
      id: 'shipPart',
      names: [ 'engine core', 'power battery', 'flow regulator',
        'fuel injector port', 'power conduit', 'power relay',
        'sig suppressor', 'reactor', 'crystal matrix',
        'wave converter', 'containment unit', 'bypass circuit',
        'emitter array', 'stabilizer',
      ],
      type: 'scenario',
      unknown: 'strange device',
      isKnown: true,
    },
    {
      id: 'keycard',
      name: 'keycard',
      type: 'key',
      unknown: 'flat rectangular object',
    },
  ];
}
