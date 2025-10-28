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
  var ordeals: DivElement;
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
      
      // create bottom section with actions and ordeals
      var bottom = Browser.document.createDivElement();
      bottom.id = 'window-cult-bottom';
      
      // create actions and ordeals elements inside bottom container
      actions = addBlock(bottom, 'window-cult-actions', 'ACTIONS');
      ordeals = addBlock(bottom, 'window-cult-ordeals', 'ORDEALS', 'scroller');
      
      cont.appendChild(bottom);
      addCloseButton();
    }

// show window and reset state to root
  public override function show(?skipAnimation: Bool = false)
    {
      menuState = STATE_ROOT;
      super.show(skipAnimation);
    }

// update state from outside
  public function setMenuState(s: _UICultState)
    {
      menuState = s;
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
      for (name in _CultPower.namesUpper)
        buf.add('<th>' + Const.col('cult-power', name) + '</th>');
      buf.add('<th>' + Const.col('cult-power', Icon.money) + '</th>');
      buf.add('</tr>');
      
      // power row
      buf.add('<tr>');
      buf.add('<td class="cult-row-label">Power</td>');
      for (name in _CultPower.names)
        buf.add('<td>' + cult.power.get(name) + '</td>');
      buf.add('<td>' + cult.power.money + '</td>');
      buf.add('</tr>');
      
      // income row
      buf.add('<tr class="cult-income">');
      buf.add('<td class="cult-row-label">Income</td>');
      for (name in _CultPower.names)
        {
          var income = Std.int(cult.power.get(name) / 3);
          buf.add('<td>' + (income > 0 ? '+' + income : '-') + '</td>');
        }
      var moneyIncome = Std.int(cult.power.money * 0.5);
      buf.add('<td>' + (moneyIncome > 0 ? '+' + moneyIncome : '-') + '</td>');
      buf.add('</tr>');
      
      // resources row
      buf.add('<tr class="cult-resources">');
      buf.add('<td class="cult-row-label">Resources</td>');
      for (name in _CultPower.names)
        buf.add('<td>' + cult.resources.get(name) + '</td>');
      buf.add('<td>' + cult.resources.money + '</td>');
      buf.add('</tr>');
      buf.add('</table>');

      // members list
      buf.add('<br/>');
      for (i => m in cult.members)
        {
          buf.add(m.TheName());
          if (i == 0)
            buf.add(' ' + Const.col('gray', '(leader)'));
          buf.add(' ');
          buf.add(Const.smallgray(m.job + ', ' + 
            Const.col('white', m.income) + Icon.money));
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
      
      // ordeals list
      updateOrdeals();
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
      else if (menuState == STATE_TRADE)
        updateActionsTrade();
      
      // trigger content update animation on the whole actions block
      animate(actions);
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
      
      // action - trade (only show if at least 10k money)
      if (cult.resources.money >= 10000)
        {
          addPlayerAction({
            id: 'trade',
            type: ACTION_CULT,
            name: 'Trade ' + Icon.money,
            energy: 0,
            f: function() {
              menuState = STATE_TRADE;
              updateActions();
            }
          });
        }
      
      // action - initiate ordeal
      addPlayerAction({
        id: 'initiateOrdeal',
        type: ACTION_CULT,
        name: 'Initiate communal ordeal',
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
            name: Const.smallgray('[Ordeal] ') + ordeal.customName(),
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

// update actions for trade state
  function updateActionsTrade()
    {
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
      if (game.cults[0].resources.money < 10000)
        return;
      
      var cult = game.cults[0];
      var cost = 10000;
      
      // trade actions for each power type
      for (i in 0..._CultPower.names.length)
        {
          var power = _CultPower.names[i];
          var powerType = power; // capture the power type for the closure
          addPlayerAction({
            id: 'trade.' + power,
            type: ACTION_CULT,
            name: 'To ' + Const.col('cult-power', power) +
              ' power (' +
              Const.col('cult-power', cost) + Icon.money + ')',
            energy: 0,
            f: function() {
              cult.trade(powerType);
              update();
            }
          });
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
          if (a.obj != null &&
              a.obj.submenu == 'recruit')
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
          // set different f function based on whether obj exists
          if (a.obj != null &&
              a.obj.submenu == 'back')
            a.f = function() {
              menuState = STATE_INITIATE;
              updateActions();
            }
          else a.f = function() {
            cult.ordeals.action(a);
            menuState = STATE_ROOT;
            updateActions();
          }
          addPlayerAction(a);
        }
    }

// update actions for individual ordeal state
  function updateActionsOrdeal()
    {
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
            addPlayerAction(action);
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
        update();
      };
      actions.appendChild(actionElement);
    }

// update ordeals list
  function updateOrdeals()
    {
      var cult = game.cults[0];
      var previousHTML = ordeals.innerHTML;
      var newHTML = '';
      
      if (cult.ordeals.list.length == 0)
        {
          newHTML = '<div class="window-empty">No active ordeals</div>';
        }
      else
        {
          var buf = new StringBuf();
          var n = 0;
          for (ordeal in cult.ordeals.list)
            {
              addOrdealCard(buf, ordeal, (n % 2 == 0));
              n++;
            }
          newHTML = buf.toString();
        }
      
      ordeals.innerHTML = newHTML;
      if (newHTML != previousHTML)
        animate(ordeals, 'ordeals-updating');
    }

// add ordeal card (col 0 or 1)
  function addOrdealCard(buf: StringBuf, ordeal: Ordeal, isCol0: Bool)
    {
      if (isCol0)
        buf.add('<div class="window-cult-ordeals-row">');
      
      buf.add('<div class="window-cult-ordeals-card">');
      
      // title
      buf.add('<div class="window-cult-ordeals-title">');
      buf.add(ordeal.customName());
      buf.add('</div>');
      
      // note
      if (ordeal.note != '')
        {
          buf.add('<div class="window-cult-ordeals-note">');
          buf.add(ordeal.note);
          buf.add('</div>');
        }
      
      // members
      buf.add('<div class="window-cult-ordeals-members">');
      buf.add('Members: ');
      if (ordeal.members.length == 0)
        {
          buf.add('None');
        }
      else
        {
          var cult = game.cults[0];
          var memberNames = [];
          for (memberID in ordeal.members)
            {
              var member = null;
              for (m in cult.members)
                if (m.id == memberID)
                  {
                    member = m;
                    break;
                  }
              if (member != null)
                memberNames.push(member.TheName());
            }
          buf.add(memberNames.join(', '));
        }
      buf.add('</div>');
      
      // power
      buf.add('<div class="window-cult-ordeals-power">');
      var powerParts = [];
      if (ordeal.power.combat > 0)
        powerParts.push('COMBAT ' + Const.col('white', ordeal.power.combat));
      if (ordeal.power.media > 0)
        powerParts.push('MEDIA ' + Const.col('white', ordeal.power.media));
      if (ordeal.power.lawfare > 0)
        powerParts.push('LAWFARE ' + Const.col('white', ordeal.power.lawfare));
      if (ordeal.power.corporate > 0)
        powerParts.push('CORPORATE ' + Const.col('white', ordeal.power.corporate));
      if (ordeal.power.political > 0)
        powerParts.push('POLITICAL ' + Const.col('white', ordeal.power.political));
      if (ordeal.power.money > 0)
        powerParts.push(Const.col('white', ordeal.power.money) + Icon.money);
      
      if (powerParts.length > 0)
        buf.add('Power: ' + powerParts.join(', '));
      else
        buf.add('No power requirements');
      buf.add('</div>');
      
      // actions counter
      buf.add('<div class="window-cult-ordeals-actions">');
      buf.add('Actions used: ' + ordeal.actions + '/' + ordeal.members.length);
      buf.add('</div>');
      
      buf.add('</div>');
      
      if (!isCol0)
        buf.add('</div>');
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
