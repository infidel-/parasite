// ordeal base class for cult challenges
package cult;

import game.Game;
import cult.Cult;
import _CultPower;
import _OrdealType;
import _PlayerAction;
import Icon;
import Reflect;
import ai.AIData;

class Ordeal extends _SaveObject
{
  static var _ignoredFields = [ 'cult' ];
  public var game: Game;
  public var name: String;
  public var members: Array<Int>; // cult members involved
  public var power: _CultPower;
  public var type: _OrdealType;
  public var requiredMembers: Int;
  public var requiredMemberLevels: Int;
  public var cult(get, never): Cult;
  private function get_cult(): Cult
    {
      return game.cults[0];
    }

  public function new(g: Game)
    {
      game = g;
      members = [];
      requiredMembers = 0;
      requiredMemberLevels = 0;
      power = {
        combat: 0,
        media: 0,
        lawfare: 0,
        corporate: 0,
        political: 0,
        occult: 0,
        money: 0
      };

// will be called by sub-classes
//      init();
//      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      type = ORDEAL_COMMUNAL;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {}

// add member to ordeal
  public function addMembers(memberIDs: Array<Int>)
    {
      for (memberID in memberIDs)
        {
          if (members.indexOf(memberID) == -1)
            members.push(memberID);
        }
    }

// get custom name for display
  public function customName(): String
    {
      return name;
    }

// handle member death
  public function onDeath(aidata: AIData)
    {
    }

// fail this ordeal
  public function fail()
    {
      cult.ordeals.fail(this);
    }

// get actions available for this ordeal
  public function getActions(): Array<_PlayerAction>
    {
      var actions: Array<_PlayerAction> = [];
      var powerFields = ['combat', 'media', 'lawfare', 'corporate', 'political'];
      
      for (field in powerFields)
        {
          var powerAmount: Int = Reflect.getProperty(power, field);
          var cultAmount: Int = Reflect.getProperty(cult.resources, field);
          
          if (powerAmount > 0 &&
              cultAmount >= powerAmount)
            {
              var displayName = Const.col('cult-power', '' + powerAmount) + ' ' + field + ' power';
              actions.push({
                id: 'spend.' + field,
                type: ACTION_CULT,
                name: 'Wield ' + displayName,
                energy: 0,
                f: function() {
                  Reflect.setProperty(cult.resources, field, cultAmount - powerAmount);
                  Reflect.setProperty(power, field, 0);
                  cult.log('exerted ' + displayName + ' on ' +
                    Const.col('gray', name) + ' ordeal');
                  game.ui.updateWindow();
                }
              });
            }
        }
      
      // spend money action (handled separately)
      if (power.money > 0 &&
          cult.resources.money >= power.money)
        {
          var displayName = Const.col('cult-power', '' + power.money) + Icon.money;
          actions.push({
            id: 'spendMoney',
            type: ACTION_CULT,
            name: 'Disburse ' + displayName,
            energy: 0,
            f: function() {
              cult.resources.money -= power.money;
              cult.log('disbursed ' + displayName + ' on ' + Const.col('gray', name) + ' ordeal');
              game.ui.updateWindow();
            }
          });
        }
      
      return actions;
    }
}
