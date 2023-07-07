// body GUI window - inventory/skills/organs

package jsui;

import js.Browser;
import js.html.DivElement;
import js.html.LegendElement;
import js.html.Element;

import game.Game;
import game.Improv;
import game.Organs;
import game.EvolutionManager;
import const.*;
import const.EvolutionConst;

class Body extends UIWindow
{
  var inventoryList: DivElement;
  var inventoryTitle: LegendElement;
  var inventoryActions: DivElement;
  var skillsParasite: DivElement;
  var skillsHost: DivElement;
  var organsList: DivElement;
  var organsTitle: LegendElement;
  var organsAvailable: DivElement;
  var organsInfo: DivElement;
  var organsActions: DivElement;
  var listInventoryActions: Array<_PlayerAction>;
  var listOrgansActions: Array<_PlayerAction>;
  var actionPrefix: String; // action prefix: inventory or body

  public function new(g: Game)
    {
      super(g, 'window-body');
      listInventoryActions = [];
      listOrgansActions = [];
      window.style.borderImage = "url('./img/window-body.png') 234 fill / 1 / 0 stretch";

      // columns
      var col1 = Browser.document.createDivElement();
      col1.id = 'window-body-col1';
      window.appendChild(col1);
      var col2 = Browser.document.createDivElement();
      col2.id = 'window-body-col2';
      window.appendChild(col2);

      // inventory
      var cont = addBlock(col1, 'window-inventory-contents', 'INVENTORY', 'window-contents-wrapper');
      var ret = addBlockExtended(cont, 'window-inventory-list', 'ITEMS');
      inventoryList = ret.text;
      inventoryTitle = ret.legend;
      inventoryActions = addBlock(cont, 'window-inventory-actions', 'ACTIONS');

      // skills
      var cont = addBlock(col1, 'window-skills-contents', 'KNOWLEDGE', 'window-contents-wrapper');
      skillsParasite = addBlock(cont, 'window-skills-parasite', 'PARASITE');
      skillsHost = addBlock(cont, 'window-skills-host', 'HOST');
      skillsHost.innerHTML = 'skills host';

      // organs
      var cont = addBlock(col2, 'window-organs-contents', 'BODY', 'window-contents-wrapper');
      var ret = addBlockExtended(cont, 'window-organs-list', 'FEATURES');
      organsList = ret.text;
      organsTitle = ret.legend;
      organsAvailable = addBlock(cont, 'window-organs-available', 'AVAILABLE FEATURES');
      organsInfo = addBlock(cont, 'window-organs-info', 'INFO');
      organsActions = addBlock(cont, 'window-organs-actions', 'ACTIONS');
      organsActions.innerHTML = 'actions list';

      addCloseButton();
    }

// update window contents
  override function update()
    {
      updateInventoryActions();
      updateOrgansActions();
      setParams({
        inventoryList: updateInventoryList(),
        skillsParasite: updateSkillsParasite(),
        skillsHost: updateSkillsHost(),
        organsList: updateOrgansList(),
        organsInfo: updateOrgansInfo(),
        organsAvailable: updateOrgansAvailable(),
      });
    }

// add organ or improvement info
  function addOrgan(buf: StringBuf, imp: Improv)
    {
      var impInfo = imp.info;
      var organInfo = impInfo.organ;
      // can be null!
      var organ = game.player.host.organs.get(impInfo.id);
      var isActive = (organ != null ? organ.isActive : false);
      var currentGP = 0;
      if (organ != null)
        currentGP = organ.gp;

      buf.add('<div class=window-organs-list-item>');
      buf.add("<span style='color:var(--text-color-organ-title" +
        (isActive ? '' : '-inactive') + ")'>" +
        organInfo.name + "</span>");
      buf.add(' ');
      var organLevel = (organ != null ? organ.level : imp.level);
      buf.add(organLevel);
      if (isActive)
        {
          if (organInfo.hasTimeout && organ.timeout > 0)
            buf.add(' (timeout: ' + organ.timeout + ')');
        }
      else buf.add(' (' + currentGP + '/' + organInfo.gp + ' gp)');
      buf.add("<p class=small style='color:var(--text-color-evolution-note);margin: 0px;'>" + organInfo.note + '</p>');
      buf.add('<p class=window-evolution-list-notes>');
      var levelNote = impInfo.levelNotes[organLevel];
      if (levelNote.indexOf('fluff') < 0 &&
        levelNote.indexOf('todo') < 0 &&
        levelNote != '')
      buf.add("<span style='color:var(--text-color-evolution-level-note)'>" + levelNote + '</span><br/>');
      if (impInfo.noteFunc != null)
        buf.add("<span style='color:var(--text-color-evolution-params)'>" +
          impInfo.noteFunc(impInfo.levelParams[organLevel], null) +
          '</span><br/>');
      buf.add('</p>');
      buf.add('</div>');
    }

// update organs list
  function updateOrgansList(): String
    {
      if (game.player.state != PLR_STATE_HOST)
        return '';
      organsTitle.innerHTML = 'FEATURES ' + Const.smallgray('[' +
        game.player.host.organs.length() + '/' +
        game.player.host.maxOrgans + ']');
      var buf = new StringBuf();
      for (organ in game.player.host.organs)
        addOrgan(buf, game.player.evolutionManager.getImprov(organ.id));
      if (game.player.host.organs.length() == 0)
        buf.add('<center>no body features</center>');

      return buf.toString();
    }

// update available organs list
  function updateOrgansAvailable(): String
    {
      if (game.player.state != PLR_STATE_HOST)
        return '';
      var buf = new StringBuf();
      var hasOrgans = false;
      for (imp in game.player.evolutionManager)
        {
          // improvement not available yet or no organs
          if (imp.level == 0 || imp.info.organ == null)
            continue;

          // organ already completed
          if (game.player.host.organs.getActive(imp.info.id) != null)
            continue;

          addOrgan(buf, imp);
          hasOrgans = true;
        }
      if (!hasOrgans)
        buf.add('<center>no features available</center><br/>');
      return buf.toString();
    }

// update organs info
  function updateOrgansInfo(): String
    {
      if (game.player.state != PLR_STATE_HOST)
        return '';
      var buf = new StringBuf();
      buf.add('<p class=small>');
      if (game.location == LOCATION_AREA && game.area.isHabitat)
        buf.add('You are in a microhabitat. ');
      buf.add('Body feature growth costs additional ' +
        __Math.growthEnergyPerTurn() +
        ' energy per turn. ' +
        'You will receive ' + __Math.gpPerTurn() + ' gp per turn. ' +
        'Your host will survive for ' +
          Std.int(game.player.host.energy /
            __Math.growthEnergyPerTurn()) +
        ' turns while growing body features (not counting other spending). ');
      buf.add('</p>');

      buf.add('<span class=small>');
      buf.add('<br/>Growing body feature: ');
      buf.add(game.player.host.organs.getGrowInfo());
      buf.add('</span>');
      return buf.toString();
    }

// update organs actions
  function updateOrgansActions()
    {
      listOrgansActions = [];
      organsActions.innerHTML = '';
      // disable organs actions in region mode for now
      if (game.location == LOCATION_REGION ||
          game.player.state != PLR_STATE_HOST ||
          game.player.host.organs.length() >= game.player.host.maxOrgans)
        return;

      var n = 1;
      for (imp in game.player.evolutionManager)
        {
          // improvement not available yet or no organs
          if (imp.level == 0 || imp.info.organ == null)
            continue;

          // organ already completed
          if (game.player.host.organs.getActive(imp.info.id) != null)
            continue;

          var organInfo = imp.info.organ;
          // can be null!
          var organ = game.player.host.organs.get(imp.info.id);
          var currentGP = 0;
          if (organ != null)
            currentGP = organ.gp;
          var gpLeft = organInfo.gp - currentGP;
          var act: _PlayerAction = {
            id: 'set.' + imp.id,
            type: ACTION_ORGAN,
            name: Const.col('organ-title', organInfo.name) +
              ' ' + imp.level + ' (' + organInfo.gp + ' gp) (' +
              Math.round(gpLeft / __Math.gpPerTurn()) + " turns)",
            energy: 0,
          };

          // html element
          var action = Browser.document.createDivElement();
          action.className = 'actions-item';
          action.innerHTML = Const.key('S-' + n) + ': ' + act.name;
          n++;
          action.onclick = function (e) {
            game.scene.sounds.play('click-action');
            game.player.host.organs.action(act.id);
            update();
            game.ui.hud.update();
          };
          organsActions.appendChild(action);
          listOrgansActions.push(act);
        }
    }

// update inventory list
  function updateInventoryList(): String
    {
      if (game.player.state != PLR_STATE_HOST)
        return '';
      inventoryTitle.innerHTML = 'INVENTORY ' + Const.smallgray('[' +
        game.player.host.inventory.length() + '/' +
        game.player.host.maxItems + ']');
      var buf = new StringBuf();
      var n = 0;
      for (item in game.player.host.inventory)
        {
          n++;
          var knowsItem = game.player.knowsItem(item.id);
          var name = (knowsItem ? item.name : item.info.unknown);
          buf.add(Const.col('inventory-item', name) + '<br/>');
        }

      if (n == 0)
        buf.add('<center>no items</center><br/>');

      return buf.toString();
    }

// update inventory actions
  function updateInventoryActions()
    {
      inventoryActions.innerHTML = '';
      if (game.player.state != PLR_STATE_HOST)
        return;
      listInventoryActions = game.player.host.inventory.getActions();
      var n = 1;
      for (act in listInventoryActions)
        {
          // reduce cost when host is agreeable
          if (act.isAgreeable &&
              game.player.hostAgreeable())
            act.energy = 1;
          // html element
          var action = Browser.document.createDivElement();
          action.className = 'actions-item';
          action.innerHTML = Const.key('C-' + n) + ': ' + act.name +
            (act.energy > 0 ? Const.cost(act.energy) : '');
          n++;
          action.onclick = function (e) {
            game.scene.sounds.play('click-action');
            game.player.host.inventory.action(act);
            if (game.ui.state == UISTATE_BODY)
              game.ui.closeWindow();
          };
          inventoryActions.appendChild(action);
        }
    }

// update parasite skills
  function updateSkillsParasite(): String
    {
      var buf = new StringBuf();
      // parasite skills
      var n = 0;
      for (skill in game.player.skills.sorted())
        {
          n++;
          if (skill.info.group != null)
            buf.add(skill.info.group + ': ');
          else if (skill.info.isKnowledge)
            buf.add('Knowledge: ');
          buf.add(Const.col('skill-title', skill.info.name));
          if (skill.info.isBool == null || !skill.info.isBool)
            buf.add(' ' + skill.level + '%<br/>');
          else buf.add('<br/>');
        }

      if (n == 0)
        buf.add('<center>no skills</center><br/>');

      if (game.player.evolutionManager.isKnown(IMP_MICROHABITAT) &&
          game.player.vars.habitatsLeft < 100)
        buf.add('Habitats left: ' + game.player.vars.habitatsLeft + '<br>');

      // get group/team info
      game.group.getInfo(buf);

      return buf.toString();
    }

// update host skills
  function updateSkillsHost(): String
    {
      if (game.player.state != PLR_STATE_HOST)
        return '';
      var buf = new StringBuf();
      var n = 0;
      for (skill in game.player.host.skills.sorted())
        {
          // hidden animal attack skill
          if (skill.info.id == SKILL_ATTACK)
            continue;

          n++;
          if (skill.info.group != null)
            buf.add(skill.info.group + ': ');
          buf.add(Const.col('skill-title',
            skill.info.name));
          if (skill.info.isBool == null ||
              !skill.info.isBool)
            buf.add(' ' + skill.level + '%<br/>');
          else buf.add('<br/>');
        }

      if (n == 0)
        buf.add('<center>no useful knowledge</center><br/>');

      // host attributes and traits
      if (!game.player.host.isAttrsKnown)
        {
          if (game.player.host.hasTrait(TRAIT_ASSIMILATED))
            {
              var info = TraitsConst.getInfo(TRAIT_ASSIMILATED);
              buf.add('<br/><span class=host-attr-title>' +
                info.name + '</span><br/>');
              buf.add('<span class=host-attr-notes>' + info.note +
                '</span><br/>');
            }
        }
      else
        {
          // traits
          if (game.player.host.traits.length > 0)
            {
              buf.add('<br/>');
              for (t in game.player.host.traits)
                {
                  var info = TraitsConst.getInfo(t);
                  buf.add('<span class=host-attr-title>' +
                    info.name + '</span><br/>');
                  buf.add('<span class=host-attr-notes>' + info.note +
                    '</span><br/>');
                }
            }
          buf.add('<br/>');
          buf.add('<span class=host-attr-title>Strength ' + game.player.host.strength + '</span><br/>');
          buf.add('<span class=host-attr-notes>' +
            'Increases health and energy<br/>' +
            'Increases melee damage<br/>' +
            'Decreases grip efficiency<br/>' +
            'Decreases paralysis efficiency<br/>' +
            'Increases speed of freeing from mucus<br/>' +
            'Limits the amount of inventory items<br/>' +
            '</span><br/>');

          buf.add('<span class=host-attr-title>Constitution ' + game.player.host.constitution + '</span><br/>');
          buf.add('<span class=host-attr-notes>' +
            'Increases health and energy<br/>' +
            'Limits the amount of body features<br/>' +
            '</span><br/>');

          buf.add('<span class=host-attr-title>Intellect ' + game.player.host.intellect + '</span><br/>');
          buf.add('<span class=host-attr-notes>' +
            'Increases skills and society knowledge learning efficiency<br/>' +
            '</span><br/>');

          buf.add('<span class=host-attr-title>Psyche ' + game.player.host.psyche + '</span><br/>');
          buf.add('<span class=host-attr-notes>' +
            'Increases energy needed to probe brain<br/>' +
            'Reduces the efficiency of reinforcing control<br/>' +
            '</span><br/>');

        }
      return buf.toString();
    }

// set action prefix
  public function prefix(p: String)
    {
      actionPrefix = p;
    }

// action buttons need to be prefixed
  public override function action(index: Int)
    {
      if (actionPrefix == null)
        {
          game.log('No prefix selected.', COLOR_HINT);
        }
      else if (actionPrefix == 'inventory')
        {
          if (!game.player.vars.inventoryEnabled)
            return;
          var a = listInventoryActions[index - 1];
          if (a == null)
            return;
          game.player.host.inventory.action(a);
          if (game.ui.state == UISTATE_BODY)
            game.ui.closeWindow();
        }
      else if (actionPrefix == 'body')
        {
          var a = listOrgansActions[index - 1];
          if (a == null)
            return;
          game.player.host.organs.action(a.id);
          update();
          game.ui.hud.update();
        }
      actionPrefix = null;
    }

  function e(id: String): Element
    {
      return Browser.document.getElementById(id);
    }

  public override function setParams(obj: Dynamic)
    {
      inventoryList.innerHTML = obj.inventoryList;
      skillsParasite.innerHTML = obj.skillsParasite;
      skillsHost.innerHTML = obj.skillsHost;
      organsList.innerHTML = obj.organsList;
      organsAvailable.innerHTML = obj.organsAvailable;
      organsInfo.innerHTML = obj.organsInfo;
      e('window-inventory-contents').className = '';
      e('window-inventory-list').className = '';
      e('window-inventory-actions').className = '';
      e('window-skills-contents').className = '';
      e('window-skills-parasite').className = '';
      e('window-skills-host').className = '';
      e('window-organs-contents').className = '';
      e('window-organs-available').className = '';
      e('window-organs-actions').className = '';
      e('window-organs-list').className = '';
      e('window-organs-info').className = '';
      if (game.player.state != PLR_STATE_HOST ||
          !game.player.host.isHuman ||
          !game.player.vars.inventoryEnabled)
        {
          e('window-inventory-contents').className = 'window-disabled';
          e('window-inventory-list').className = 'window-disabled';
          e('window-inventory-actions').className = 'window-disabled';
        }
      if (!game.player.vars.skillsEnabled)
        {
          e('window-skills-contents').className = 'window-disabled';
          e('window-skills-parasite').className = 'window-disabled';
          e('window-skills-host').className = 'window-disabled';
        }
      if (game.player.state != PLR_STATE_HOST ||
          !game.player.vars.organsEnabled)
        {
          e('window-organs-contents').className = 'window-disabled';
          e('window-organs-available').className = 'window-disabled';
          e('window-organs-actions').className = 'window-disabled';
          e('window-organs-list').className = 'window-disabled';
          e('window-organs-info').className = 'window-disabled';
        }
    }
}
