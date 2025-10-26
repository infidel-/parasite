// cult stats/actions GUI window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;
import _UICultState;
import cult.Ordeal;

class Cult extends UIWindow
{
  var info: DivElement;
  var actions: DivElement;
  var listActions: Array<_PlayerAction>;
  var menuState: _UICultState; // current state
  var currentOrdeal: Ordeal; // currently selected ordeal

  public function new(g: Game)
    {
      super(g, 'window-cult');
      listActions = [];
      menuState = STATE_ROOT;
      window.style.borderImage = "url('./img/window-evolution.png') 210 fill / 1 / 0 stretch";

      var cont = Browser.document.createDivElement();
      cont.id = 'window-cult-contents';
      window.appendChild(cont);

      info = addBlock(cont, 'window-cult-info', 'INFO', 'scroller');
      actions = addBlock(cont, 'window-cult-actions', 'ACTIONS');
      addCloseButton();
    }

// show window and reset state to root
  public override function show(?skipAnimation: Bool = false)
    {
      menuState = STATE_ROOT;
      super.show(skipAnimation);
    }

// update window contents
  override function update()
    {
      // info block
      var buf = new StringBuf();
      buf.add('<span>');
      var cult = game.cults[0];

      // cult power and resources table
      buf.add('<table class="cult-table">');
      buf.add('<tr>');
      buf.add('<th></th>'); // empty header for row labels
      buf.add('<th>' + Const.col('cult-power', 'COMBAT') + '</th>');
      buf.add('<th>' + Const.col('cult-power', 'MEDIA') + '</th>');
      buf.add('<th>' + Const.col('cult-power', 'LAWFARE') + '</th>');
      buf.add('<th>' + Const.col('cult-power', 'CORPORATE') + '</th>');
      buf.add('<th>' + Const.col('cult-power', 'POLITICAL') + '</th>');
      buf.add('<th>' + Const.col('cult-power', Icon.money) + '</th>');
      buf.add('</tr>');
      
      // power row
      buf.add('<tr>');
      buf.add('<td class="cult-row-label">Power</td>');
      buf.add('<td>' + cult.power.combat + '</td>');
      buf.add('<td>' + cult.power.media + '</td>');
      buf.add('<td>' + cult.power.lawfare + '</td>');
      buf.add('<td>' + cult.power.corporate + '</td>');
      buf.add('<td>' + cult.power.political + '</td>');
      buf.add('<td>' + cult.power.money + '</td>');
      buf.add('</tr>');
      
      // income row
      buf.add('<tr class="cult-income">');
      buf.add('<td class="cult-row-label">Income</td>');
      buf.add('<td>' + (Std.int(cult.power.combat / 3) > 0 ? '+' + Std.int(cult.power.combat / 3) : '-') + '</td>');
      buf.add('<td>' + (Std.int(cult.power.media / 3) > 0 ? '+' + Std.int(cult.power.media / 3) : '-') + '</td>');
      buf.add('<td>' + (Std.int(cult.power.lawfare / 3) > 0 ? '+' + Std.int(cult.power.lawfare / 3) : '-') + '</td>');
      buf.add('<td>' + (Std.int(cult.power.corporate / 3) > 0 ? '+' + Std.int(cult.power.corporate / 3) : '-') + '</td>');
      buf.add('<td>' + (Std.int(cult.power.political / 3) > 0 ? '+' + Std.int(cult.power.political / 3) : '-') + '</td>');
      buf.add('<td>' + (Std.int(cult.power.money * 0.5) > 0 ? '+' + Std.int(cult.power.money * 0.5) : '-') + '</td>');
      buf.add('</tr>');
      
      // resources row
      buf.add('<tr class="cult-resources">');
      buf.add('<td class="cult-row-label">Resources</td>');
      buf.add('<td>' + cult.resources.combat + '</td>');
      buf.add('<td>' + cult.resources.media + '</td>');
      buf.add('<td>' + cult.resources.lawfare + '</td>');
      buf.add('<td>' + cult.resources.corporate + '</td>');
      buf.add('<td>' + cult.resources.political + '</td>');
      buf.add('<td>' + cult.resources.money + '</td>');
      buf.add('</tr>');
      buf.add('</table>');

      // members list
      buf.add('<br/>');
      for (i => m in cult.members)
        {
          buf.add(m.TheName());
          if (i == 0)
            buf.add(' (leader)');
          buf.add('<br/>');
        }
      buf.add('</span><br/>');
      buf.add('<span class=gray>Members: ' +
        cult.members.length + '/' + cult.maxSize() + '</span><br/>');
      var infotext = buf.toString();
      setParams({
        info: infotext,
      });

      // actions list
      updateActions();
    }

// update list of actions
  function updateActions()
    {
      listActions = [];
      actions.innerHTML = '';

      if (menuState == STATE_ROOT)
        updateActionsRoot();
      else if (menuState == STATE_INITIATE)
        updateActionsInitiate();
      else if (menuState == STATE_RECRUIT)
        updateActionsRecruit();
      else if (menuState == STATE_ORDEAL)
        updateActionsOrdeal();
    }

// update actions for root state
  function updateActionsRoot()
    {
      var cult = game.cults[0];
      
      // action - call for help
      if (cult.canCallHelp())
        {
          var a: _PlayerAction = {
            id: 'callHelp',
            type: ACTION_CULT,
            name: 'Summon the faithful',
            energy: 0,
          }
          a.f = function() {
            game.cults[0].action(a);
            game.ui.closeWindow();
          }
          addPlayerAction(a);
        }
      
      // action - initiate ordeal
      addPlayerAction({
        id: 'initiateOrdeal',
        type: ACTION_CULT,
        name: 'Initiate ordeal',
        energy: 0,
        f: function() {
          menuState = STATE_INITIATE;
          updateActions();
        }
      });
      
      // list of current ordeals
      for (ordeal in cult.ordeals.list)
        {
          var ordealAction: _PlayerAction = {
            id: 'ordeal_' + ordeal.name,
            type: ACTION_CULT,
            name: Const.smallgray('[Ordeal] ') + ordeal.name,
            energy: 0,
            obj: { ordeal: ordeal }
          };
          
          var ordealObj = ordeal; // capture the ordeal object
          ordealAction.f = function() {
            currentOrdeal = ordealObj;
            menuState = STATE_ORDEAL;
            updateActions();
          };
          
          addPlayerAction(ordealAction);
        }
    }

// update actions for initiate state
  function updateActionsInitiate()
    {
      var cult = game.cults[0];
      
      // back button
      addPlayerAction({
        id: 'back',
        type: ACTION_CULT,
        name: 'Back',
        energy: 0,
        f: function() {
          menuState = STATE_ROOT;
          updateActions();
        }
      });
      
      // get ordeal actions from cult.ordeals
      var ordealActions = cult.ordeals.getInitiateOrdealActions();
      for (a in ordealActions)
        {
          // check if this action opens a submenu before creating closure
          if (a.obj != null && a.obj.submenu == 'recruit')
            {
              a.f = function() {
                menuState = STATE_RECRUIT;
                updateActions();
              }
            }
          else
            {
              var actionObj = a; // capture the action object
              a.f = function() {
                cult.ordeals.action(actionObj);
                menuState = STATE_ROOT;
                updateActions();
              }
            }
          addPlayerAction(a);
        }
    }

// update actions for recruit state
  function updateActionsRecruit()
    {
      var cult = game.cults[0];
      
      // get recruit actions from cult.ordeals
      var recruitActions = cult.ordeals.getRecruitActions();
      for (a in recruitActions)
        {
          a.f = function() {
            // check if this is back action
            if (a.obj != null && a.obj.submenu == 'back')
              {
                menuState = STATE_INITIATE;
                updateActions();
              }
            else
              {
                cult.ordeals.action(a);
                menuState = STATE_ROOT;
                updateActions();
              }
          }
          addPlayerAction(a);
        }
    }

// update actions for individual ordeal state
  function updateActionsOrdeal()
    {
      var cult = game.cults[0];
      
      // back button
      addPlayerAction({
        id: 'back',
        type: ACTION_CULT,
        name: 'Back',
        energy: 0,
        f: function() {
          menuState = STATE_ROOT;
          updateActions();
        }
      });
      
      // get actions from the current ordeal
      if (currentOrdeal != null)
        {
          var ordealActions = currentOrdeal.getActions();
          for (action in ordealActions)
            {
              addPlayerAction(action);
            }
        }
    }

// add player action helper method
  function addPlayerAction(action: _PlayerAction)
    {
      var n = listActions.length + 1;
      listActions.push(action);
      var actionElement = Browser.document.createDivElement();
      actionElement.className = 'actions-item';
      actionElement.innerHTML = Const.key('' + n) + ': ' + action.name;
      actionElement.onclick = function (e) {
        game.scene.sounds.play('click-action');
        if (action.f != null)
          action.f();
      };
      actions.appendChild(actionElement);
    }

// run mouse/key action
  public override function action(index: Int)
    {
      var a = listActions[index - 1];
      if (a == null)
        return;
      
      if (a.f != null)
        a.f();
    }

  public override function setParams(obj: Dynamic)
    {
      info.innerHTML = obj.info;
//      text.scrollTop = 10000;
    }
}
