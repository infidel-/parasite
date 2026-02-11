// shared helper functions for cult event scripting
package cult;

import Const;
import Const.d100;
import ai.AIData;
import cult.Cult;
import const.TraitsConst;

class EventHelper
{
// rounds numbers upward when halving payout adjustments
  public static function halfCeil(amount: Int): Int
    {
      return Std.int((amount + 1) / 2);
    }

// rolls resource payout using 2/5/10 tier chances
  public static function rollResourcePayout(): Int
    {
      var amount = 2;
      var roll = d100();
      if (roll < 5)
        amount = 10;
      else if (roll < 30)
        amount = 5;
      return amount;
    }

// rolls money payout using 2/5/10 tier chances
  public static function rollMoneyPayout(): Int
    {
      var base = rollResourcePayout();
      return base * 10000;
    }

// adds a random trait from the group when it is safe to do so
  public static function addTrait(cult: Cult, targetID: Int, groupID: String, positiveOnly: Bool): _TraitInfo
    {
      var member = cult.getMemberByID(targetID);
      if (member == null)
        return null;
      if (groupID != 'misc' &&
          hasTraitFromGroup(member, groupID))
        return null;

      var info: _TraitInfo = null;
      if (positiveOnly)
        info = TraitsConst.getRandomPositive(groupID);
      else
        info = TraitsConst.getRandom(groupID);
      if (info == null || info.id == TRAIT_ASSIMILATED)
        return null;
      if (!member.addTrait(info.id))
        return null;
      member.logsg('embraces the ' + Const.col('trait', info.name) + ' calling.');
      return info;
    }

// checks if member already holds a trait from a given group
  public static function hasTraitFromGroup(member: AIData, groupID: String): Bool
    {
      var group = TraitsConst.getGroup(groupID);
      if (group == null)
        return false;
      for (entry in group)
        {
          if (member.hasTrait(entry.id))
            return true;
        }
      return false;
    }
}
