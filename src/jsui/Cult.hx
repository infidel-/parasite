// cult stats/actions GUI window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;
import _UICultState;

class Cult extends UIWindow
{
  var info: DivElement;
  var actions: DivElement;
  var listActions: Array<_PlayerAction>;
  var menuState: _UICultState; // current state

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

      // cult power
      buf.add('Power: ');
      buf.add(Const.col('cult-power-title', 'COMBAT') + ' ' + cult.power.combat);
      buf.add(', ');
      buf.add(Const.col('cult-power-title', 'MEDIA') + ' ' + cult.power.media);
      buf.add(', ');
      buf.add(Const.col('cult-power-title', 'LAWFARE') + ' ' + cult.power.lawfare);
      buf.add(', ');
      buf.add(Const.col('cult-power-title', 'CORPORATE') + ' ' + cult.power.corporate);
      buf.add(', ');
      buf.add(Const.col('cult-power-title', 'POLITICAL') + ' ' + cult.power.political);
      buf.add(', ');
      buf.add(Const.col('cult-power-title', 'INCOME') + ' ' + cult.power.money);

      // cult resources
      buf.add('<br/>Resources: ');
      buf.add(Const.col('cult-power-title', 'COMBAT') + ' ' + cult.resources.combat);
      buf.add(', ');
      buf.add(Const.col('cult-power-title', 'MEDIA') + ' ' + cult.resources.media);
      buf.add(', ');
      buf.add(Const.col('cult-power-title', 'LAWFARE') + ' ' + cult.resources.lawfare);
      buf.add(', ');
      buf.add(Const.col('cult-power-title', 'CORPORATE') + ' ' + cult.resources.corporate);
      buf.add(', ');
      buf.add(Const.col('cult-power-title', 'POLITICAL') + ' ' + cult.resources.political);
      buf.add(', ');
      buf.add(Const.col('cult-power-title', Icon.money) + ' ' + cult.resources.money);
      buf.add('<br/>');

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
            name: 'Call for help',
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
          a.f = function() {
            cult.ordeals.action(a);
            game.ui.closeWindow();
          }
          addPlayerAction(a);
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
