// cult bazaar menu helper

package ui;

import ai.AIData;
import const.Bazaar;
import game.Game;
import game._Item;

private typedef _TrainingOption = {
  var amount: Int;
  var moneyCost: Int;
  var combatCost: Int;
}

private typedef _TrainActionArgs = {
  var member: AIData;
  var weapon: _Item;
  var lane: String;
  var idPrefix: String;
}

class CultBazaar
{
  var game: Game;
  var cultWindow: Cult;
  var selectedMemberID: Int;

  public function new(g: Game, cultWindow: Cult)
    {
      game = g;
      this.cultWindow = cultWindow;
      selectedMemberID = -1;
    }

// checks whether any bazaar item is affordable
  public function hasAffordableItems(): Bool
    {
      var cult = game.cults[0];
      var resources = cult.resources;
      for (price in Bazaar.bazaarPrices)
        if (resources.money >= price.money &&
            resources.combat >= price.combat)
          return true;
      return false;
    }

// builds root bazaar menu
  public function showRoot()
    {
      cultWindow.addPlayerAction({
        id: 'back',
        type: ACTION_CULT,
        name: 'Back',
        energy: 0,
        f: function() {
          cultWindow.setMenuState(STATE_ROOT);
          cultWindow.updateActions();
        }
      });

      var canAfford = hasAffordableItems();
      var equipLabel = (canAfford ? 'Equip member' :
        Const.col('gray', 'Equip member'));
      cultWindow.addPlayerAction({
        id: 'bazaarEquip',
        type: ACTION_CULT,
        name: equipLabel,
        energy: 0,
        f: (canAfford ? function() {
          cultWindow.setMenuState(STATE_BAZAAR_MEMBER);
          cultWindow.updateActions();
        } : null)
      });

      cultWindow.addPlayerAction({
        id: 'bazaarTrain',
        type: ACTION_CULT,
        name: 'Train member',
        energy: 0,
        f: function() {
          cultWindow.setMenuState(STATE_BAZAAR_TRAIN_MEMBER);
          cultWindow.updateActions();
        }
      });
    }

// builds list of free members to equip
  public function showMemberList()
    {
      cultWindow.addPlayerAction({
        id: 'back',
        type: ACTION_CULT,
        name: 'Back',
        energy: 0,
        f: function() {
          cultWindow.setMenuState(STATE_BAZAAR);
          cultWindow.updateActions();
        }
      });

      var cult = game.cults[0];
      for (m in cult.members)
        {
          if (cult.getMemberStatus(m.id) != '')
            continue;
          var memberID = m.id;
          cultWindow.addPlayerAction({
            id: 'bazaarMember',
            type: ACTION_CULT,
            name: m.TheName(),
            energy: 0,
            obj: { memberID: memberID },
            f: function() {
              selectedMemberID = memberID;
              cultWindow.setMenuState(STATE_BAZAAR_EQUIP);
              cultWindow.updateActions();
            }
          });
        }
    }

// builds list of free members to train
  public function showTrainMemberList()
    {
      cultWindow.addPlayerAction({
        id: 'back',
        type: ACTION_CULT,
        name: 'Back',
        energy: 0,
        f: function() {
          cultWindow.setMenuState(STATE_BAZAAR);
          cultWindow.updateActions();
        }
      });

      var cult = game.cults[0];
      for (m in cult.members)
        {
          if (cult.getMemberStatus(m.id) != '')
            continue;
          var memberID = m.id;
          cultWindow.addPlayerAction({
            id: 'bazaarTrainMember',
            type: ACTION_CULT,
            name: m.TheName(),
            energy: 0,
            obj: { memberID: memberID },
            f: function() {
              selectedMemberID = memberID;
              cultWindow.setMenuState(STATE_BAZAAR_TRAIN_SKILL);
              cultWindow.updateActions();
            }
          });
        }
    }

// builds list of trainable weapon skills
  public function showTrainSkillList()
    {
      cultWindow.addPlayerAction({
        id: 'back',
        type: ACTION_CULT,
        name: 'Back',
        energy: 0,
        f: function() {
          cultWindow.setMenuState(STATE_BAZAAR_TRAIN_MEMBER);
          cultWindow.updateActions();
        }
      });

      var cult = game.cults[0];
      var member = cult.getMemberByID(selectedMemberID);
      if (member == null)
        return;

      // melee weapon training options
      var added = false;
      var meleeWeapon = member.inventory.getCurrentMeleeWeapon();
      if (meleeWeapon != null &&
          meleeWeapon.info.weapon != null)
        {
          if (addTrainingActions({
            member: member,
            weapon: meleeWeapon,
            lane: 'melee',
            idPrefix: 'bazaarTrainMelee'
          }))
            added = true;
        }

      // ranged weapon training options
      var rangedWeapon = member.inventory.getCurrentRangedWeapon();
      if (rangedWeapon != null &&
          rangedWeapon.info.weapon != null)
        {
          if (addTrainingActions({
            member: member,
            weapon: rangedWeapon,
            lane: 'ranged',
            idPrefix: 'bazaarTrainRanged'
          }))
            added = true;
        }

      if (!added)
        cultWindow.addPlayerAction({
          id: 'bazaarTrainNone',
          type: ACTION_CULT,
          name: Const.col('gray', 'No trainable weapon skills'),
          energy: 0,
        });
    }

// builds training amount options for selected member skill
  function getTrainingAmountOptions(member: AIData, skillID: _Skill, lane: String): Array<_TrainingOption>
    {
      var options: Array<_TrainingOption> = [];
      if (skillID == null)
        return options;

      var currentLevel = member.skills.getLevel(skillID);
      var remaining = 70 - currentLevel;
      if (remaining <= 0)
        return options;

      var tiers = [10, 20];
      for (tier in tiers)
        {
          var amount = tier;
          if (currentLevel + amount > 70)
            amount = Std.int(Math.ceil(remaining));
          if (amount <= 0)
            continue;

          var exists = false;
          for (entry in options)
            if (entry.amount == amount)
              {
                exists = true;
                break;
              }
          if (exists)
            continue;

          var costs = getTrainingCosts(lane, tier);
          options.push({
            amount: amount,
            moneyCost: costs.moneyCost,
            combatCost: costs.combatCost
          });
        }

      options.sort(function(a, b) {
        return a.amount - b.amount;
      });
      return options;
    }

// returns fixed training costs by lane and tier
  function getTrainingCosts(lane: String, tier: Int): { moneyCost: Int, combatCost: Int }
    {
      if (lane == 'melee')
        {
          if (tier <= 10)
            return { moneyCost: 5000, combatCost: 1 };
          return { moneyCost: 10000, combatCost: 2 };
        }

      if (tier <= 10)
        return { moneyCost: 10000, combatCost: 2 };
      return { moneyCost: 20000, combatCost: 4 };
    }

// adds one training action entry for melee or ranged weapon skill
  function addTrainingAction(args: _TrainActionArgs, option: _TrainingOption)
    {
      var weaponName = args.weapon.getName();
      var cult = game.cults[0];
      var canAfford =
        (cult.resources.money >= option.moneyCost &&
         cult.resources.combat >= option.combatCost);
      var text = weaponName + ' +' + option.amount + '% (' +
        Const.col('cult-power', option.moneyCost) + Icon.money + ', ' +
        Const.col('cult-power', option.combatCost) + ' COM)';
      var label = (canAfford ? text : Const.col('gray', text));
      cultWindow.addPlayerAction({
        id: args.idPrefix + '.' + option.amount,
        type: ACTION_CULT,
        name: label,
        energy: 0,
        f: (canAfford ? function() {
          trainMemberSkill(args, option);
          cultWindow.update();
        } : null)
      });
    }

// adds all training action entries for a lane
  function addTrainingActions(args: _TrainActionArgs): Bool
    {
      if (args.weapon == null ||
          args.weapon.info.weapon == null)
        return false;
      var skillID = args.weapon.info.weapon.skill;
      var options = getTrainingAmountOptions(args.member, skillID, args.lane);
      if (options.length == 0)
        return false;
      for (option in options)
        addTrainingAction(args, option);
      return true;
    }

// trains selected member weapon skill and applies lock
  function trainMemberSkill(args: _TrainActionArgs, option: _TrainingOption)
    {
      var cult = game.cults[0];
      if (cult.hasEffect(CULT_EFFECT_NOTRADE))
        {
          game.actionFailed('Trade rites are sealed at the moment.');
          return;
        }
      if (cult.resources.money < option.moneyCost)
        {
          game.actionFailed('Not enough money for training.');
          return;
        }
      if (cult.resources.combat < option.combatCost)
        {
          game.actionFailed('Not enough combat resources for training.');
          return;
        }

      var member = cult.getMemberByID(args.member.id);
      if (member == null)
        {
          game.actionFailed('No such member.');
          return;
        }
      if (cult.getMemberStatus(args.member.id) != '')
        {
          game.actionFailed('Only free members can train.');
          return;
        }

      if (args.weapon == null ||
          args.weapon.info.weapon == null)
        {
          game.actionFailed('No valid weapon for training.');
          return;
        }

      var skillID = args.weapon.info.weapon.skill;
      var currentLevel = member.skills.getLevel(skillID);
      if (currentLevel >= 70)
        {
          game.actionFailed('This skill is already at the training cap.');
          return;
        }
      var trainAmount: Float = option.amount;
      if (currentLevel + trainAmount > 70)
        trainAmount = 70 - currentLevel;
      if (trainAmount <= 0)
        {
          game.actionFailed('This skill is already at the training cap.');
          return;
        }

      if (!cult.setTraining(args.member.id))
        {
          game.actionFailed('Only free members can train.');
          return;
        }

      // if the skill is missing, start from its default level before applying training
      if (member.skills.has(skillID))
        member.skills.increase(skillID, trainAmount);
      else member.skills.addID(skillID, currentLevel + trainAmount);
      cult.resources.money -= option.moneyCost;
      cult.resources.combat -= option.combatCost;
      cult.recalc();
      // after training, return to follower picker for quicker consecutive assignments
      cultWindow.setMenuState(STATE_BAZAAR_TRAIN_MEMBER);
      cultWindow.updateActions();
      game.logsg(member.TheName() + ' trains ' + args.weapon.getName() +
        ' by ' + Std.int(trainAmount) + '%.');
    }

// builds list of equipment options for a member
  public function showEquipList()
    {
      cultWindow.addPlayerAction({
        id: 'back',
        type: ACTION_CULT,
        name: 'Back',
        energy: 0,
        f: function() {
          cultWindow.setMenuState(STATE_BAZAAR_MEMBER);
          cultWindow.updateActions();
        }
      });

      var cult = game.cults[0];
      var member = cult.getMemberByID(selectedMemberID);
      if (member == null)
        return;

      var items = [
        {
          name: 'Random Melee',
          itemID: 'randomMelee',
          price: getPrice('randomMelee'),
          slot: 'melee',
          isRandom: true
        },
        {
          name: 'Pistol',
          itemID: 'pistol',
          price: getPrice('pistol'),
          slot: 'ranged',
          isRandom: false
        },
        {
          name: 'Assault Rifle',
          itemID: 'assaultRifle',
          price: getPrice('assaultRifle'),
          slot: 'ranged',
          isRandom: false
        },
        {
          name: 'Combat Shotgun',
          itemID: 'combatShotgun',
          price: getPrice('combatShotgun'),
          slot: 'ranged',
          isRandom: false
        },
        {
          name: 'Kevlar Armor',
          itemID: 'kevlarArmor',
          price: getPrice('kevlarArmor'),
          slot: 'armor',
          isRandom: false
        }
      ];

      for (entry in items)
        {
          if (!entry.isRandom &&
              memberHasItem(member, entry.itemID))
            continue;

          var canAfford =
            (cult.resources.money >= entry.price.money &&
             cult.resources.combat >= entry.price.combat);
          var text = entry.name + ' (' +
            Const.col('cult-power', entry.price.money) + Icon.money + ', ' +
            Const.col('cult-power', entry.price.combat) + ' COM)';
          var label = (canAfford ? text : Const.col('gray', text));
          var itemID = entry.itemID;
          var price = entry.price;
          var slot = entry.slot;
          var isRandom = entry.isRandom;
          var memberID = selectedMemberID;
          cultWindow.addPlayerAction({
            id: 'bazaarBuy.' + itemID,
            type: ACTION_CULT,
            name: label,
            energy: 0,
            f: (canAfford ? function() {
              buyItem(memberID, itemID, price, slot, isRandom);
              cultWindow.update();
            } : null)
          });
        }
    }

// returns price for a bazaar item id
  function getPrice(itemID: String): _CultPower
    {
      var price = Bazaar.bazaarPrices.get(itemID);
      if (price == null)
        return new _CultPower();
      return price;
    }

// checks whether member already has item
  function memberHasItem(member: AIData, itemID: String): Bool
    {
      if (member.inventory.clothing != null &&
          member.inventory.clothing.id == itemID)
        return true;
      return member.inventory.has(itemID);
    }

// removes current item from the specified slot
  function removeSlotItem(member: AIData, slot: String)
    {
      var inventory = member.inventory;
      if (slot == 'armor')
        return;

      for (item in inventory)
        {
          if (item.info.weapon == null)
            continue;
          if (slot == 'ranged' &&
              item.info.weapon.isRanged)
            {
              inventory.removeItem(item);
              return;
            }
          if (slot == 'melee' &&
              !item.info.weapon.isRanged)
            {
              inventory.removeItem(item);
              return;
            }
        }
    }

// rolls a random melee item id for bazaar
  function pickRandomMeleeID(): String
    {
      var total = 0;
      for (entry in Bazaar.bazaarRandomMelee)
        total += entry.weight;
      if (total <= 0)
        return 'knife';

      var roll = Std.random(total);
      for (entry in Bazaar.bazaarRandomMelee)
        {
          if (roll < entry.weight)
            return entry.id;
          roll -= entry.weight;
        }

      return Bazaar.bazaarRandomMelee[0].id;
    }

// buys a bazaar item for a member
  function buyItem(memberID: Int, itemID: String, price: _CultPower, slot: String, isRandom: Bool)
    {
      var cult = game.cults[0];
      if (cult.hasEffect(CULT_EFFECT_NOTRADE))
        {
          game.actionFailed('Trade rites are sealed at the moment.');
          return;
        }
      if (cult.resources.money < price.money)
        {
          game.actionFailed('Not enough money for purchase.');
          return;
        }
      if (cult.resources.combat < price.combat)
        {
          game.actionFailed('Not enough combat resources for purchase.');
          return;
        }

      var member = cult.getMemberByID(memberID);
      if (member == null)
        {
          game.actionFailed('No such member.');
          return;
        }
      if (cult.getMemberStatus(memberID) != '')
        {
          game.actionFailed('Only free members can be equipped.');
          return;
        }

      var finalID = itemID;
      if (isRandom)
        finalID = pickRandomMeleeID();

      if (!isRandom &&
          memberHasItem(member, finalID))
        {
          game.actionFailed('This member already has this item.');
          return;
        }

      removeSlotItem(member, slot);

      game.player.addKnownItem(finalID);
      cult.resources.money -= price.money;
      cult.resources.combat -= price.combat;
      if (slot == 'armor')
        member.inventory.addID(finalID, true);
      else member.inventory.addID(finalID);
    }
}
