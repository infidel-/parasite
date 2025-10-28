// ordeal base class for cult challenges
package cult;

import game.Game;
import cult.Cult;
import _CultPower;
import _OrdealType;
import _PlayerAction;
import Icon;
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
  public var actions: Int;
  public var note: String;
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
      actions = 0;
      note = '';

// will be called by sub-classes
//      init();
//      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      type = ORDEAL_COMMUNAL;
      power = {
        combat: 0,
        media: 0,
        lawfare: 0,
        corporate: 0,
        political: 0,
        occult: 0,
        money: 0
      };
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

// check if ordeal is complete
  public function check()
    {
      // check if all powers are at zero
      if (power.combat == 0 &&
          power.media == 0 &&
          power.lawfare == 0 &&
          power.corporate == 0 &&
          power.political == 0 &&
          power.money == 0)
        {
          success();
        }
    }

// complete an ordeal successfully
  public function success()
    {
      onSuccess();
      cult.ordeals.success(this);
    }

// get actions available for this ordeal
  public function getActions(): Array<_PlayerAction>
    {
      // check if we can still perform actions
      var actions = [];
      if (this.actions >= members.length)
        return actions;
      
      for (field in _CultPower.names)
        {
          var powerAmount: Int = power.get(field);
          var cultAmount: Int = cult.resources.get(field);
          
          if (powerAmount > 0 &&
              cultAmount >= powerAmount)
            {
              var displayName = Const.col('cult-power', powerAmount) + ' ' + field + ' power';
              actions.push({
                id: 'spend.' + field,
                type: ACTION_CULT,
                name: 'Wield ' + displayName,
                energy: 0,
                f: function() {
                  cult.resources.dec(field, powerAmount);
                  power.set(field, 0);
                  this.actions++;
                  cult.log('exerted ' + displayName + ' on ' +
                    Const.col('gray', name) + ' ordeal');
                  check();
                  game.ui.updateWindow();
                }
              });
            }
        }
      
      // spend money action (handled separately)
      if (power.money > 0 &&
          cult.resources.money >= power.money)
        {
          var displayName = Const.col('cult-power', power.money) + Icon.money;
          actions.push({
            id: 'spend.money',
            type: ACTION_CULT,
            name: 'Disburse ' + displayName,
            energy: 0,
            f: function() {
              cult.resources.money -= power.money;
              this.power.money = 0;
              this.actions++;
              cult.log('disbursed ' + displayName + ' on ' + Const.col('gray', name) + ' ordeal');
              check();
              game.ui.updateWindow();
            }
          });
        }
      
      // cancel ordeal
      actions.push({
        id: 'annul',
        type: ACTION_CULT,
        name: 'Annul ' + Const.smallgray('(results in failure)'),
        energy: 0,
        f: function() {
          fail();
          game.ui.cult.setMenuState(STATE_ROOT);
          game.ui.updateWindow();
        }
      });
      
      return actions;
    }

// hook for when ordeal succeeds (override in subclasses)
  function onSuccess() {}
}
