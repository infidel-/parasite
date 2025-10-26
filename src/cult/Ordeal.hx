// ordeal base class for cult challenges
package cult;

import game.Game;
import cult.Cult;
import _CultPower;
import _OrdealType;
import _PlayerAction;
import Icon;

class Ordeal extends _SaveObject
{
  static var _ignoredFields = [ 'cult' ];
  public var game: Game;
  public var name: String;
  public var members: Array<Int>; // cult members involved
  public var power: _CultPower;
  public var type: _OrdealType;
  
  // getter for cult
  public var cult(get, never): Cult;
  private function get_cult(): Cult
    {
      return game.cults[0];
    }

  public function new(g: Game)
    {
      game = g;
      members = [];
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

// get actions available for this ordeal
  public function getActions(): Array<_PlayerAction>
    {
      var actions: Array<_PlayerAction> = [];
      
      // spend money action
      if (power.money > 0 &&
          cult.resources.money >= power.money)
        {
          actions.push({
            id: 'spendMoney',
            type: ACTION_CULT,
            name: 'Spend money ' + Const.smallgray('(' + power.money + Icon.money + ')'),
            energy: 0,
            f: function() {
              cult.resources.money -= power.money;
              cult.log('spent ' + Const.col('cult-power', '' + power.money) + Icon.money + ' on ' + Const.col('gray', name) + ' ordeal');
              game.ui.updateWindow();
            }
          });
        }
      
      return actions;
    }
}
