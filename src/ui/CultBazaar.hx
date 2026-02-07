// cult bazaar menu helper

package ui;

import ai.AIData;
import const.Bazaar;
import game.Game;

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
      var money = cult.resources.money;
      for (price in Bazaar.bazaarPrices)
        if (money >= price)
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
      var label = (canAfford ? 'Equip member' :
        Const.col('gray', 'Equip member'));
      cultWindow.addPlayerAction({
        id: 'bazaarEquip',
        type: ACTION_CULT,
        name: label,
        energy: 0,
        f: (canAfford ? function() {
          cultWindow.setMenuState(STATE_BAZAAR_MEMBER);
          cultWindow.updateActions();
        } : null)
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

          var canAfford = (cult.resources.money >= entry.price);
          var text = entry.name + ' (' +
            Const.col('cult-power', entry.price) + Icon.money + ')';
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
  function getPrice(itemID: String): Int
    {
      var price = Bazaar.bazaarPrices.get(itemID);
      if (price == null)
        return 0;
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
  function buyItem(memberID: Int, itemID: String, price: Int, slot: String, isRandom: Bool)
    {
      var cult = game.cults[0];
      if (cult.hasEffect(CULT_EFFECT_NOTRADE))
        {
          game.actionFailed('Trade rites are sealed at the moment.');
          return;
        }
      if (cult.resources.money < price)
        {
          game.actionFailed('Not enough money for purchase.');
          return;
        }

      var member = cult.getMemberByID(memberID);
      if (member == null)
        {
          game.actionFailed('No such member.');
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
      cult.resources.money -= price;
      if (slot == 'armor')
        member.inventory.addID(finalID, true);
      else member.inventory.addID(finalID);
    }
}
