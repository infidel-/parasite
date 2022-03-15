// body GUI window - inventory/skills/organs

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;
import game.EvolutionManager;
import const.EvolutionConst;

class Body extends UIWindow
{
  var inventoryList: DivElement;
  var inventoryActions: DivElement;
  var skillsParasite: DivElement;
  var skillsHost: DivElement;
  var organsList: DivElement;
  var organsAvailable: DivElement;
  var organsInfo: DivElement;
  var organsActions: DivElement;
  var listInventoryActions: Array<_PlayerAction>;

  public function new(g: Game)
    {
      super(g, 'window-body');
      listInventoryActions = [];
      window.style.borderImage = "url('./img/window-evolution.png') 210 fill / 1 / 0 stretch";

      // columns
      var col1 = Browser.document.createDivElement();
      col1.id = 'window-body-col1';
      window.appendChild(col1);
      var col2 = Browser.document.createDivElement();
      col2.id = 'window-body-col2';
      window.appendChild(col2);

      // inventory
      var cont = addBlock(col1, 'window-inventory-contents', 'INVENTORY');
      inventoryList = addBlock(cont, 'window-inventory-list', 'ITEMS');
      inventoryActions = addBlock(cont, 'window-inventory-actions', 'ACTIONS');

      // skills
      var cont = addBlock(col1, 'window-skills-contents', 'KNOWLEDGE');
      skillsParasite = addBlock(cont, 'window-skills-parasite', 'PARASITE');
      skillsParasite.innerHTML = 'skills parasite';
      skillsHost = addBlock(cont, 'window-skills-host', 'HOST');
      skillsHost.innerHTML = 'skills host';

      // organs
      var cont = addBlock(col2, 'window-organs-contents', 'BODY', 'window-organs-contents-wrapper');
      organsList = addBlock(cont, 'window-organs-list', 'FEATURES');
      organsList.innerHTML = 'organs list';
      organsAvailable = addBlock(cont, 'window-organs-available', 'AVAILABLE FEATURES');
      organsAvailable.innerHTML = 'available organs list';
      organsInfo = addBlock(cont, 'window-organs-info', 'INFO');
      organsInfo.innerHTML = 'organs list';
      organsActions = addBlock(cont, 'window-organs-actions', 'ACTIONS');
      organsActions.innerHTML = 'actions list';
    }

// update window contents
  override function update()
    {
      updateInventoryActions();
      setParams({
        inventoryList: updateInventoryList(),
      });
    }

// update inventory list
  function updateInventoryList(): String
    {
      var buf = new StringBuf();
      var n = 0;
      for (item in game.player.host.inventory)
        {
          n++;
          var knowsItem = game.player.knowsItem(item.id);
          var name = (knowsItem ? item.name : item.info.unknown);
          buf.add(name + '<br/>');
        }

      if (n == 0)
        buf.add('  --- empty ---<br/>');

      return buf.toString();
    }

// update inventory actions
  function updateInventoryActions()
    {
      listInventoryActions = game.player.host.inventory.getActions();
      inventoryActions.innerHTML = '';
      var n = 1;
      for (act in listInventoryActions)
        {
          // html element
          var action = Browser.document.createDivElement();
          action.className = 'actions-item';
          action.innerHTML = 'i' + n + ': ' + act.name +
            (act.energy > 0 ? ' (' + act.energy + ' energy)' : '');
          n++;
          action.onclick = function (e) {
            game.player.host.inventory.action(act);
            if (game.ui.state == UISTATE_BODY)
              game.ui.closeWindow();
          };
          inventoryActions.appendChild(action);
        }
    }

// TODO: i/b prefix support
  public override function action(index: Int)
    {
      var a = listInventoryActions[index - 1];
      if (a == null)
        return;

      game.player.host.inventory.action(a);
      if (game.ui.state == UISTATE_BODY)
        game.ui.closeWindow();
    }

  public override function setParams(obj: Dynamic)
    {
      inventoryList.innerHTML = obj.inventoryList;
    }
}
