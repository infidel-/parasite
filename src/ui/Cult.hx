// cult stats/actions GUI window

package ui;

import js.Browser;
import js.html.DivElement;
import js.html.SpanElement;

import game.Game;
import ai.AIData;
import _UICultState;
import _PlayerAction;
import cult.*;
import cult.ordeals.*;

class Cult extends UIWindow
{
  var statsEl: SpanElement; // titlebar level pill + members chip
  var info: DivElement;     // ledger + summary + roster section
  var actions: DivElement;  // ACTIONS list container
  var ordeals: DivElement;  // ORDEALS rite-cards grid
  var listActions: Array<_PlayerAction>;
  var animateActions: Bool = false; // true only during a click-driven rebuild (action cascade)
  var ordealsSeen: Array<Ordeal>; // ordeals whose entrance animation already finished
  var ordealsPending: Array<Ordeal>; // ordeals mid-entrance (keep the .new class across rebuilds)
  var ordealsPrev: Array<Ordeal>; // ordeals rendered last pass (to detect removals)
  var ordealsExiting: Array<Ordeal>; // ordeals removed from the list, still playing exit anim
  var menuState: _UICultState; // current state
  var currentOrdeal: Ordeal; // currently selected ordeal
  var bazaar: CultBazaar;
  var trade: CultTrade;

  public function new(g: Game)
    {
      super(g, 'window-cult');
      listActions = [];
      ordealsSeen = [];
      ordealsPending = [];
      ordealsPrev = [];
      ordealsExiting = [];
      menuState = STATE_ROOT;
      bazaar = new CultBazaar(g, this);
      trade = new CultTrade(g, this);

      // shared HUD chrome: scrim + pentagram glyph, frame, corners, veins, "CULT" watermark
      addHudChrome('CULT', UISvg.pentagram());

      // title row: insane FontdinerSwanky name (per-letter jitter) + stat-chip strip
      var title = Browser.document.createDivElement();
      title.className = 'win-title win-titlebar';
      var name = Browser.document.createSpanElement();
      name.className = 'cult-name';
      // split the name into per-letter spans so each glyph jitters on its own clock
      var nameBuf = new StringBuf();
      var txt = 'Cultus Carnis';
      for (i in 0...txt.length)
        {
          var ch = txt.charAt(i);
          if (ch == ' ')
            nameBuf.add(' ');
          else
            nameBuf.add('<span class="cult-l" style="--n:' + i + '">' + ch + '</span>');
        }
      name.innerHTML = nameBuf.toString();
      title.appendChild(name);
      statsEl = Browser.document.createSpanElement();
      statsEl.className = 'win-stats';
      title.appendChild(statsEl);
      window.appendChild(title);

      // scroll surface holds the psychedelic aura behind all content
      var scroll = Browser.document.createDivElement();
      scroll.className = 'cult-scroll';
      scroll.innerHTML = '<div class="cult-aura" aria-hidden="true"></div>';
      window.appendChild(scroll);

      // INFO: ledger + summary + roster
      info = Browser.document.createDivElement();
      info.className = 'cult-info cult-rise';
      info.style.setProperty('--i', '0');
      scroll.appendChild(info);

      // ACTIONS + ORDEALS bottom row
      var bottom = Browser.document.createDivElement();
      bottom.className = 'cult-bottom';
      scroll.appendChild(bottom);

      var actionsSec = Browser.document.createDivElement();
      actionsSec.className = 'cult-section cult-actions-sec cult-rise';
      actionsSec.style.setProperty('--i', '1');
      actionsSec.innerHTML = '<div class="cult-bk">ACTIONS</div>';
      actions = Browser.document.createDivElement();
      actions.className = 'cult-actions';
      actionsSec.appendChild(actions);
      bottom.appendChild(actionsSec);

      var ordealsSec = Browser.document.createDivElement();
      ordealsSec.className = 'cult-section cult-ordeals cult-rise';
      ordealsSec.style.setProperty('--i', '2');
      ordealsSec.innerHTML = '<div class="cult-bk">ORDEALS</div>';
      ordeals = Browser.document.createDivElement();
      ordeals.className = 'cult-rites';
      ordealsSec.appendChild(ordeals);
      bottom.appendChild(ordealsSec);

      addWinClose();
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
      updateStats();

      // INFO ledger + summary + roster
      var buf = new StringBuf();
      updatePowerAndResources(buf);
      updateSummary(buf);
      updateMembers(buf);
      info.innerHTML = buf.toString();

      // actions list
      updateActions();

      // ordeals list
      updateOrdeals();
    }

// titlebar level pill + members chip
  function updateStats()
    {
      var cult = game.cults[0];
      statsEl.innerHTML =
        '<span class="cult-lvl">LVL ' + cult.level + '</span>' +
        '<span class="statchip cult-members evolution-tip" data-tip="Members / maximum congregation">' +
        UISvg.cultMembers() + cult.members.length + '/' + cult.maxSize() + '</span>';
    }

// builds base / rivals / effects summary lines
  function updateSummary(buf: StringBuf)
    {
      var cult = game.cults[0];
      buf.add('<div class="cult-summary">');

      // base
      if (cult.base != null)
        buf.add('<div class="cult-line"><span class="cult-k">Base</span> ' +
          cult.base.statusText() + '</div>');

      // rival cults
      var rivals = game.getRivalCults();
      if (rivals.length > 0)
        {
          buf.add('<div class="cult-line"><span class="cult-k">Rival cults</span></div>');
          for (rival in rivals)
            buf.add('<div class="cult-line cult-rival">' + rival.name + ' ' +
              Const.smallgray('[revealed ' + rival.rivalRevealedLevel +
              '/3' + (rival.state == CULT_STATE_DEAD ? ', destroyed' : '') + ']') +
              '</div>');
        }

      // active effects
      var effectsText = collectEffects();
      if (effectsText.length > 0)
        buf.add('<div class="cult-line"><span class="cult-k">Effects</span> ' +
          effectsText.join(', ') + '</div>');

      buf.add('</div>');
    }

// update list of actions
  public function updateActions()
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
            trade.showTrade();
          case STATE_SELECT_RESOURCE:
            trade.showSelectResource();
          case STATE_TRADE_RESOURCE:
            trade.showTradeResource();
          case STATE_UPGRADE:
            updateActionsUpgrade();
          case STATE_UPGRADE_TWO:
            updateActionsUpgradeTwo();
          case STATE_CALL_MEMBER:
            updateActionsCallMember();
          case STATE_BAZAAR:
            bazaar.showRoot();
          case STATE_BAZAAR_MEMBER:
            bazaar.showMemberList();
          case STATE_BAZAAR_EQUIP:
            bazaar.showEquipList();
          case STATE_BAZAAR_TRAIN_MEMBER:
            bazaar.showTrainMemberList();
          case STATE_BAZAAR_TRAIN_SKILL:
            bazaar.showTrainSkillList();
        }
    }

// update actions for root state
  function updateActionsRoot()
    {
      var cult = game.cults[0];
      var inMissionArea =
        (game.location == LOCATION_AREA &&
         game.area != null &&
         game.area.isMissionArea());
     
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
      if (!inMissionArea &&
          cult.resources.money >= 10000 &&
          !cult.hasEffect(CULT_EFFECT_NOTRADE))
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

      // action - trade resources (only show if at least 3 of any resource and no trade restriction)
      if (!inMissionArea &&
          !cult.hasEffect(CULT_EFFECT_NOTRADE))
        {
          var hasResources = false;
          for (name in _CultPower.names)
            {
              if (cult.resources.get(name) >=
                  cult.getTradeResourceCost())
                {
                  hasResources = true;
                  break;
                }
            }
          
          if (hasResources)
            addPlayerAction({
              id: 'tradeResources',
              type: ACTION_CULT,
              name: 'Trade resources',
              energy: 0,
              f: function() {
                menuState = STATE_SELECT_RESOURCE;
                updateActions();
              }
            });
        }

      // action - bazaar
      if (!inMissionArea &&
          !cult.hasEffect(CULT_EFFECT_NOTRADE))
        {
          var canAfford = bazaar.hasAffordableItems();
          var label = (canAfford ? 'BazaarNet' : Const.col('gray', 'BazaarNet'));
          addPlayerAction({
            id: 'bazaar',
            type: ACTION_CULT,
            name: label,
            energy: 0,
            f: (canAfford ? function() {
              menuState = STATE_BAZAAR;
              updateActions();
            } : null)
          });
        }

      // action - initiate ordeal
      if (!inMissionArea)
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
      if (!inMissionArea)
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

// builds power/income/resource ledger (power values carry a magnitude micro-bar)
  function updatePowerAndResources(buf: StringBuf)
    {
      var cult = game.cults[0];

      // peak power for micro-bar normalization
      var maxP = 1;
      for (name in _CultPower.names)
        {
          var p = cult.power.get(name);
          if (p > maxP)
            maxP = p;
        }

      buf.add('<div class="cult-panel cult-ledger-wrap">');
      buf.add('<table class="cult-ledger">');

      // header
      buf.add('<tr class="cult-lhead"><th></th>');
      for (name in _CultPower.namesUpper)
        buf.add('<th>' + name + '</th>');
      buf.add('<th class="cult-money">' + Icon.money + '</th></tr>');

      // power row (white values + bar)
      buf.add('<tr class="cult-prow"><td class="cult-rl">Power</td>');
      for (name in _CultPower.names)
        {
          var p = cult.power.get(name);
          buf.add('<td style="--v:' + Std.int(p / maxP * 100) + '">' + p + '</td>');
        }
      buf.add('<td>' + cult.power.money + '</td></tr>');

      // income row (green)
      buf.add('<tr class="cult-income"><td class="cult-rl">Income</td>');
      for (name in _CultPower.names)
        {
          var income = Std.int(cult.power.get(name) / 3);
          buf.add('<td>' + (income > 0 ? '+' + income : '-') + '</td>');
        }
      var moneyIncome = Std.int(cult.power.money * 0.5);
      buf.add('<td>' + (moneyIncome > 0 ? '+' + moneyIncome : '-') + '</td></tr>');

      // resources row (gray)
      buf.add('<tr class="cult-res"><td class="cult-rl">Resources</td>');
      for (name in _CultPower.names)
        buf.add('<td>' + cult.resources.getShort(name) + '</td>');
      buf.add('<td>' + cult.resources.getShort('money') + '</td></tr>');

      buf.add('</table></div>');
    }

// builds congregation roster (leader sigil, host row dimmed, gear slots)
  function updateMembers(buf: StringBuf)
    {
      var cult = game.cults[0];
      buf.add('<div class="cult-panel cult-roster-wrap">');
      buf.add('<table class="cult-roster"><thead><tr>');
      buf.add('<th>name</th><th>occupation</th><th>income</th><th>health</th>' +
        '<th>energy</th><th>status</th><th>armor / ranged / melee</th>');
      buf.add('</tr></thead><tbody>');
      for (i => m in cult.members)
        {
          var status = cult.getMemberStatus(m.id);
          var isHost = (status == '[host]');
          var rowCls = (i == 0 ? ' class="cult-leader"' : (isHost ? ' class="cult-host"' : ''));
          buf.add('<tr' + rowCls + '>');

          // name (+ leader tag)
          buf.add('<td><span class="cult-mn">' + m.TheName() + '</span>' +
            (i == 0 ? ' <span class="cult-tag">(leader)</span>' : '') + '</td>');

          // occupation
          var jobInfo = game.jobs.getJobInfo(m.job);
          buf.add('<td class="cult-sg">[' + jobInfo.level + '] ' + m.job + '</td>');

          // income (struck when inactive)
          if (status != '')
            buf.add('<td><s class="cult-sg">' + m.income + Icon.money + '</s></td>');
          else
            buf.add('<td class="cult-w">' + m.income + Icon.money + '</td>');

          // health / energy
          if (isHost)
            buf.add('<td class="cult-sg">-</td><td class="cult-sg">-</td>');
          else
            buf.add('<td class="cult-sg">' + m.health + '/' + m.maxHealth + '</td>' +
              '<td class="cult-sg">' + m.energy + '/' + m.maxEnergy + '</td>');

          // status
          if (isHost || status != '')
            buf.add('<td class="cult-st">' + (status != '' ? status : '-') + '</td>');
          else
            buf.add('<td class="cult-sg">-</td>');

          // gear slots
          if (isHost)
            buf.add('<td class="cult-sg">-</td>');
          else
            buf.add('<td class="cult-gear">' + memberGearHTML(m) + '</td>');

          buf.add('</tr>');
        }
      buf.add('</tbody></table></div>');
      buf.add('<div class="cult-count">Members: ' +
        cult.members.length + '/' + cult.maxSize() + '</div>');
    }

// builds the three gear slots (armor / ranged / melee) for a member row
  function memberGearHTML(member: AIData): String
    {
      // armor (no hit chance)
      var armor = null;
      var clothing = member.inventory.clothing;
      if (clothing != null &&
          clothing.id != 'armorNone')
        armor = clothing.getName();

      // first ranged + first melee weapon, with skill % as hit chance
      var ranged = null, rangedHit = 0;
      var melee = null, meleeHit = 0;
      for (item in member.inventory)
        {
          if (item.info.weapon == null)
            continue;
          var hit = Std.int(member.skills.getLevel(item.info.weapon.skill));
          if (item.info.weapon.isRanged)
            {
              if (ranged == null) { ranged = item.getName(); rangedHit = hit; }
            }
          else if (melee == null) { melee = item.getName(); meleeHit = hit; }
        }

      return giSpan(armor, -1) +
        giSpan(ranged, ranged != null ? rangedHit : -1) +
        giSpan(melee, melee != null ? meleeHit : -1);
    }

// one gear slot: item name (+ optional hit-chance pill), or dim placeholder when empty
  function giSpan(name: String, hit: Int): String
    {
      if (name == null)
        return '<span class="cult-gi cult-none">-</span>';
      var h = (hit >= 0 ? ' <i class="cult-hit">' + hit + '%</i>' : '');
      return '<span class="cult-gi">' + name + h + '</span>';
    }

// collects active cult + ordeal effect labels
  function collectEffects(): Array<String>
    {
      var cult = game.cults[0];
      var effectsText = [];

      // cult effects
      for (e in cult.effects)
        {
          var t = '<span class="cult-fx">' + e.customName() + '</span> ' +
            Const.smallgray('(' + e.turns + ' t)');
          var note = e.note();
          if (note != '')
            t += Const.smallgray(' (' + note + ')');
          effectsText.push(t);
        }

      // ordeal effects (tagged with the ordeal name)
      for (ordeal in cult.ordeals.list)
        for (e in ordeal.effects)
          {
            var t = '<span class="cult-fx">' + e.customName() + '</span> ' +
              Const.smallgray('(' + e.turns + ' t)');
            var note = e.note();
            if (note != '')
              t += Const.smallgray(' (' + note + ')');
            t += ' ' + Const.smallgray('[' + ordeal.coloredName() + ']');
            effectsText.push(t);
          }

      return effectsText;
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

// add player action helper method (keyed row: sigil key chip + name)
  public function addPlayerAction(action: _PlayerAction)
    {
      var n = listActions.length + 1;
      listActions.push(action);
      var actionElement = Browser.document.createDivElement();
      // staggered cascade on click-driven rebuild (--i drives per-row delay)
      actionElement.className = 'cult-act' + (animateActions ? ' cult-act-anim' : '');
      actionElement.style.setProperty('--i', '' + (n - 1));
      actionElement.innerHTML = '<span class="cult-key">' + n + '</span> ' + action.name;
      actionElement.onclick = function (e) {
        game.scene.sounds.play('click-action');
        animateActions = true;
        if (action.f != null)
          action.f();
        update();
        animateActions = false;
      };
      actions.appendChild(actionElement);
    }

// update ordeals list (2-col "rite" cards)
  function updateOrdeals()
    {
      var cult = game.cults[0];
      var list = cult.ordeals.list;

      // detect ordeals that left the list since last pass -> render a ghost exit card
      // for the animation, then drop it after the exit anim plays out
      for (o in ordealsPrev)
        if (list.indexOf(o) < 0
            && ordealsExiting.indexOf(o) < 0)
          {
            ordealsExiting.push(o);
            var ord = o;
            haxe.Timer.delay(function() {
              ordealsExiting.remove(ord);
              updateOrdeals();
            }, 450);
          }

      var buf = new StringBuf();

      // live cards (entrance detection)
      for (ordeal in list)
        {
          // a card animates while it is new (not yet finished entering); the .new
          // class is kept across rebuilds (action() + onclick both re-render) until
          // a timer flips it to "seen" once the entrance animation has played out
          var isNew = (ordealsSeen.indexOf(ordeal) < 0);
          if (isNew && ordealsPending.indexOf(ordeal) < 0)
            {
              ordealsPending.push(ordeal);
              var o = ordeal;
              haxe.Timer.delay(function() {
                ordealsPending.remove(o);
                if (ordealsSeen.indexOf(o) < 0)
                  ordealsSeen.push(o);
              }, 650);
            }
          addOrdealCard(buf, ordeal, isNew, false);
        }

      // ghost cards for ordeals leaving the list (exit anim)
      for (ordeal in ordealsExiting)
        addOrdealCard(buf, ordeal, false, true);

      ordeals.innerHTML = (buf.length == 0 ?
        '<div class="cult-empty">No active ordeals</div>' : buf.toString());

      // snapshot the live list; prune the seen set to currently-active ordeals
      ordealsPrev = [for (o in list) o];
      ordealsSeen = [for (o in ordealsSeen) if (list.indexOf(o) >= 0) o];
    }

// add one rite card (drippy wax edge, italic note, labeled detail rows, timer)
  function addOrdealCard(buf: StringBuf, ordeal: Ordeal, isNew: Bool, isOut: Bool)
    {
      var isProfane = (ordeal.type == ORDEAL_PROFANE);
      buf.add('<div class="cult-rite' + (isProfane ? ' cult-profane' : '') +
        (isNew ? ' cult-rite-new' : '') + (isOut ? ' cult-rite-out' : '') + '">');

      // title + note
      buf.add('<div class="cult-rt">' + ordeal.customName() + '</div>');
      if (ordeal.note != '')
        buf.add('<div class="cult-rnote">' + ordeal.note + '</div>');

      buf.add('<table class="cult-rtab">');

      // members
      var memberNames = [];
      var cult = game.cults[0];
      for (memberID in ordeal.members)
        for (m in cult.members)
          if (m.id == memberID)
            {
              memberNames.push(m.TheName());
              break;
            }
      buf.add('<tr><th>Members</th><td>' +
        (memberNames.length > 0 ? memberNames.join(', ') : 'None') + '</td></tr>');

      // power requirements
      var powerParts = [];
      if (ordeal.power.combat > 0)
        powerParts.push('COMBAT <span class="cult-w">' + ordeal.power.combat + '</span>');
      if (ordeal.power.media > 0)
        powerParts.push('MEDIA <span class="cult-w">' + ordeal.power.media + '</span>');
      if (ordeal.power.lawfare > 0)
        powerParts.push('LAWFARE <span class="cult-w">' + ordeal.power.lawfare + '</span>');
      if (ordeal.power.corporate > 0)
        powerParts.push('CORPORATE <span class="cult-w">' + ordeal.power.corporate + '</span>');
      if (ordeal.power.political > 0)
        powerParts.push('POLITICAL <span class="cult-w">' + ordeal.power.political + '</span>');
      if (ordeal.power.money > 0)
        powerParts.push('<span class="cult-w">' + ordeal.power.money + '</span>' + Icon.money);
      buf.add('<tr><th>Power</th><td>' +
        (powerParts.length > 0 ? powerParts.join(', ') :
          '<span class="cult-sg">No power requirements</span>') + '</td></tr>');

      // actions counter
      buf.add('<tr><th>Actions</th><td>' + ordeal.actions + '/' + ordeal.members.length + '</td></tr>');

      // claves (missions)
      if (ordeal.missions.length > 0)
        {
          var missionNames = [];
          for (mission in ordeal.missions)
            {
              var name = mission.coloredName();
              if (mission.isCompleted)
                name += Const.col('gray', ' [completed]');
              else name += ' ' + Const.smallgray('at (' + mission.x + ', ' + mission.y + ')');
              missionNames.push(name);
            }
          buf.add('<tr><th>Claves</th><td>' + missionNames.join(', ') + '</td></tr>');
        }

      // profane timer
      if (isProfane)
        {
          var prof: ProfaneOrdeal = cast ordeal;
          buf.add('<tr class="cult-timer"><th>Time left</th><td><span class="cult-w">' +
            prof.timer + '</span> turns</td></tr>');
        }

      buf.add('</table></div>');
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

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }
}
