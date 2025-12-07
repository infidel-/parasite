// cult stats/actions GUI window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;
import _UICultState;
import _PlayerAction;
import cult.*;
import cult.ordeals.*;

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

// reset cult UI to root state and update actions
  public function reset()
    {
      menuState = STATE_ROOT;
      updateActions();
    }

// update window contents
  override function update()
    {
      var buf = new StringBuf();
      updatePowerAndResources(buf);
      updateEffects(buf);
      updateMembers(buf);
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

      switch (menuState)
        {
          case STATE_ROOT:
            updateActionsRoot();
          case STATE_INITIATE:
            updateActionsInitiate();
          case STATE_RECRUIT:
            updateActionsRecruit();
          case STATE_ORDEAL:
            updateActionsOrdeal();
          case STATE_TRADE:
            updateActionsTrade();
          case STATE_UPGRADE:
            updateActionsUpgrade();
          case STATE_UPGRADE_TWO:
            updateActionsUpgradeTwo();
          case STATE_CALL_MEMBER:
            updateActionsCallMember();
        }
      
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
          };

          a.f = function() {
            game.cults[0].action(a);
            game.ui.closeWindow();
          }
          addPlayerAction(a);

          // action - call member
          addPlayerAction({
            id: 'callMember',
            type: ACTION_CULT,
            name: 'Summon member',
            energy: 0,
            f: function() {
              menuState = STATE_CALL_MEMBER;
              updateActions();
            }
          });
        }

      // action - trade (only show if at least 10k money)
      if (cult.resources.money >= 10000 &&
          !cult.effects.has(CULT_EFFECT_NOTRADE))
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
      var cult = game.cults[0];
      var cost = cult.getTradeCost();
      
      if (cult.resources.money < cost)
        return;
      
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

// update actions for initiate ordeal state
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
          if (a.obj != null &&
              a.obj.submenu == 'recruit')
            {
              a.f = function() {
                menuState = STATE_RECRUIT;
                updateActions();
              }
            }
          else if (a.obj != null &&
                   a.obj.submenu == 'upgrade')
            {
              a.f = function() {
                menuState = STATE_UPGRADE;
                updateActions();
              }
            }
          else if (a.obj != null &&
                   a.obj.submenu == 'upgrade2')
            {
              a.f = function() {
                menuState = STATE_UPGRADE_TWO;
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
      
      // get recruit actions from RecruitFollower
      var recruitActions = RecruitFollower.getRecruitActions(cult);
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

// update actions for upgrade state
  function updateActionsUpgrade()
    {
      var cult = game.cults[0];
      
      // get upgrade actions from cult.ordeals
      var upgradeActions = UpgradeFollower.getUpgradeActions(cult, game);
      for (a in upgradeActions)
        {
          // set different f function based on whether obj exists
          if (a.obj != null &&
              a.obj.submenu == 'back')
            a.f = function() {
              menuState = STATE_INITIATE;
              updateActions();
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

// update actions for second tier upgrade state
  function updateActionsUpgradeTwo()
    {
      var cult = game.cults[0];
      
      var upgradeActions = UpgradeFollower2.getUpgrade2Actions(cult, game);
      for (a in upgradeActions)
        {
          // back action
          if (a.obj != null &&
              a.obj.submenu == 'back')
            a.f = function() {
              menuState = STATE_INITIATE;
              updateActions();
            }
          // member to upgrade
          else
            {
              if (a.f == null)
                {
                  var actionObj = a;
                  a.f = function() {
                    cult.ordeals.action(actionObj);
                    menuState = STATE_ROOT;
                    updateActions();
                  }
                }
            }
          addPlayerAction(a);
        }
    }

// update actions for call member state
  function updateActionsCallMember()
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
      
      // list of free members
      var free = cult.getFreeMembers(1);
      for (mid in free)
        {
          var m = cult.getMemberByID(mid);
          var memberID = mid; // capture for closure
          addPlayerAction({
            id: 'callMember',
            type: ACTION_CULT,
            name: m.TheName(),
            energy: 0,
            obj: { memberID: memberID },
            f: function() {
              game.cults[0].action({
                id: 'callMember',
                type: ACTION_CULT,
                name: '',
                energy: 0,
                obj: { memberID: memberID }
              });
              game.ui.closeWindow();
            }
          });
        }
    }

// builds power and resource summary block
  function updatePowerAndResources(buf: StringBuf)
    {
      var cult = game.cults[0];
      buf.add('<span>');
      buf.add('<table class="cult-table">');
      buf.add('<tr>');
      buf.add('<th></th>');
      for (name in _CultPower.namesUpper)
        buf.add('<th>' + Const.col('cult-power', name) + '</th>');
      buf.add('<th>' + Const.col('cult-power', Icon.money) + '</th>');
      buf.add('</tr>');

      buf.add('<tr>');
      buf.add('<td class="cult-row-label">Power</td>');
      for (name in _CultPower.names)
        buf.add('<td>' + cult.power.get(name) + '</td>');
      buf.add('<td>' + cult.power.money + '</td>');
      buf.add('</tr>');

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

      buf.add('<tr class="cult-resources">');
      buf.add('<td class="cult-row-label">Resources</td>');
      for (name in _CultPower.names)
        buf.add('<td>' + cult.resources.get(name) + '</td>');
      buf.add('<td>' + cult.resources.money + '</td>');
      buf.add('</tr>');
      buf.add('</table>');
    }

// builds members table for cult overview
  function updateMembers(buf: StringBuf)
    {
      var cult = game.cults[0];
      buf.add('<br/>');
      buf.add('<table class="cult-members-table">');
      buf.add('<thead>');
      buf.add('<tr>');
      buf.add('<th>' + Const.smallgray('name') + '</th>');
      buf.add('<th>' + Const.smallgray('occupation') + '</th>');
      buf.add('<th>' + Const.smallgray('income') + '</th>');
      buf.add('<th>' + Const.smallgray('health') + '</th>');
      buf.add('<th>' + Const.smallgray('energy') + '</th>');
      buf.add('<th>' + Const.smallgray('status') + '</th>');
      buf.add('</tr>');
      buf.add('</thead>');
      buf.add('<tbody>');
      for (i => m in cult.members)
        {
          buf.add('<tr>');
          buf.add('<td>');
          buf.add(m.TheName());
          if (i == 0)
            buf.add(' ' + Const.col('gray', '(leader)'));
          buf.add('</td>');
          var jobInfo = game.jobs.getJobInfo(m.job);
          buf.add('<td>' + Const.smallgray('[' + jobInfo.level + '] ' + m.job) + '</td>');
          var status = cult.getMemberStatus(m.id);
          var income = m.income + '';
          if (status != '')
            income = '<s>' + Const.col('gray', income) + '</s>';
          else income = Const.col('white', income);

          buf.add('<td>' + income + Icon.money + '</td>');
          buf.add('<td>' + Const.smallgray(m.health + '/' + m.maxHealth) + '</td>');
          buf.add('<td>' + Const.smallgray(m.energy + '/' + m.maxEnergy) + '</td>');
          buf.add('<td>');
          if (status != '')
            buf.add(Const.smallgray(status));
          else
            buf.add(Const.smallgray('-'));
          buf.add('</td>');
          buf.add('</tr>');
        }
      buf.add('</tbody>');
      buf.add('</table>');
      buf.add('</span><br/>');
      buf.add('<span class=gray>Members: ' +
        cult.members.length + '/' + cult.maxSize() + '</span><br/>');
    }

// appends list of active cult effects
  function updateEffects(buf: StringBuf)
    {
      var cult = game.cults[0];
      var effectsText = [];
      
      // add cult effects
      for (effect in cult.effects)
        {
          effectsText.push(
            Const.col('cult-effect', effect.customName()) + ' ' +
            Const.smallgray('(' + effect.turns + ' t)'));
        }
      
      // add ordeal effects
      for (ordeal in cult.ordeals.list)
        {
          for (effect in ordeal.effects)
            {
              effectsText.push(
                Const.col('cult-effect', effect.customName()) + ' ' +
                Const.smallgray('(' + effect.turns + ' t)') + ' ' +
                Const.smallgray('[' + ordeal.coloredName() + ']'));
            }
        }
      
      if (effectsText.length == 0)
        return;
      buf.add('<span>Effects: ' + effectsText.join(', ') + '</span><br/>');
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
      buf.add(ordeal.coloredName());
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
      buf.add('Actions taken: ' + ordeal.actions + '/' + ordeal.members.length);
      buf.add('</div>');
      
      // missions list for profane ordeals
      if (ordeal.type == ORDEAL_PROFANE)
        {
          var prof: ProfaneOrdeal = cast ordeal;
          if (prof.missions.length > 0)
            {
              buf.add('<div class="window-cult-ordeals-clavis">');
              buf.add('Claves: ');
              var clavisNames = [];
              for (mission in prof.missions)
                clavisNames.push(mission.coloredName() +
                  (mission.isCompleted ? Const.col('gray', ' [completed]') : ''));
              buf.add(clavisNames.join(', '));
              buf.add('</div>');
            }
      
          // profane ordeal timer
          buf.add('<div class="window-cult-ordeals-timer">');
          buf.add('Time remaining: ' + Const.col('white', prof.timer) + ' turns');
          buf.add('</div>');
        }

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
