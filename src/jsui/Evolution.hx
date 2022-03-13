// evolution GUI window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;
import game.EvolutionManager;
import const.EvolutionConst;

class Evolution extends UIWindow
{
  var list: DivElement;
  var info: DivElement;
  var actions: DivElement;
  var listActions: Array<_PlayerAction>;

  public function new(g: Game)
    {
      super(g, 'window-evolution');
      listActions = [];
      window.style.borderImage = "url('./img/window-evolution.png') 190 fill / 1 / 0 stretch";

      var cont = Browser.document.createDivElement();
      cont.id = 'window-evolution-contents';
      window.appendChild(cont);
      list = addBlock(cont, 'window-evolution-list', 'CONTROLLED EVOLUTION: IMPROVEMENTS');
      info = addBlock(cont, 'window-evolution-info', 'INFO');
      actions = addBlock(cont, 'window-evolution-actions', 'ACTIONS');
    }

// add improvement (col 0 or 1)
  function addImp(buf: StringBuf, imp: Improv, isCol0: Bool)
    {
      if (isCol0)
        buf.add('<div class=window-evolution-list-row>');
      var diff = game.player.evolutionManager.difficulty;
      // limit by max level
      var maxLevel = imp.info.maxLevel;
      if (imp.info.id == IMP_BRAIN_PROBE || diff == EASY)
        1;
      else if (diff == NORMAL && maxLevel > 2)
        maxLevel = 2;
      else if (diff == HARD && maxLevel > 1)
        maxLevel = 1;
      var isMaxLevel = false;
      if (imp.level + 1 > maxLevel)
        isMaxLevel = true;

      // title line
      buf.add('<div class=window-evolution-list-item>');
      buf.add("<span style='color:var(--text-color-evolution-title)'>" + imp.info.name + "</span>");
      buf.add(' ');
      if (imp.info.maxLevel > 1)
        buf.add(imp.level);
      if (!isMaxLevel)
        buf.add(' => ' + (imp.level + 1));
      if (imp.level < imp.info.maxLevel)
        buf.add(' (' + imp.ep + '/' +
          EvolutionConst.epCostImprovement[imp.level] + ' ep)');
      buf.add("<br/><span style='color:var(--text-color-evolution-note)'>" + imp.info.note + '</span><br/>');

      // imp notes
      buf.add('<p class=window-evolution-list-notes>');
      var levelNote = imp.info.levelNotes[imp.level];
      var nextLevelNote = '';
      if (!isMaxLevel)
        nextLevelNote = ' => ' + imp.info.levelNotes[imp.level + 1];
      if (levelNote.indexOf('fluff') < 0 &&
          levelNote.indexOf('todo') < 0)
        buf.add("<span style='color:var(--text-color-evolution-level-note)'>" + levelNote + nextLevelNote + '</span><br/>');
      if (imp.info.noteFunc != null)
        buf.add("<span style='color:var(--text-color-evolution-params)'>" +
          imp.info.noteFunc(imp.info.levelParams[imp.level],
            (isMaxLevel ? null : imp.info.levelParams[imp.level + 1])) + '</span><br/>');
      buf.add('</p>');
      buf.add('</div>');
      if (!isCol0)
        buf.add('</div>');
    }

// update window contents
  override function update()
    {
      // improvements list
      var buf = new StringBuf();
      var n = 0;
      for (imp in game.player.evolutionManager)
        {
          addImp(buf, imp, (n % 2 == 0));
          n++;
        }
      if (n == 0)
        buf.add('  --- empty ---<br/>');
      var listtext = buf.toString();

      // info block
      var buf = new StringBuf();
      if (game.location == LOCATION_AREA && game.area.isHabitat)
        buf.add('You are in a microhabitat.<br/>');
      buf.add('Evolving costs additional ' + __Math.evolutionEnergyPerTurn() +
        ' energy per turn.<br/>' +
        'You will receive ' + __Math.epPerTurn() + ' ep per turn.<br/>' +
        'Your host will survive for ' +
          Std.int(game.player.host.energy / __Math.evolutionEnergyPerTurn()) +
        ' turns while evolving (not counting other spending).<br/>');
      buf.add('<br/>Current evolution direction: ');
      buf.add(game.player.evolutionManager.getEvolutionDirectionInfo());
      var infotext = buf.toString();

      // actions
      listActions = [];
      actions.innerHTML = '';
      var n = 1;
      // add stop action
      if (game.player.evolutionManager.isActive)
        {
          var act: _PlayerAction = {
            id: 'stop',
            type: ACTION_EVOLUTION,
            name: 'Stop evolution',
            energy: 0,
          };
          listActions.push(act);
          var action = Browser.document.createDivElement();
          action.className = 'window-evolution-actions-item';
          action.innerHTML = n + ': Stop evolution';
          action.onclick = function (e) {
            game.player.evolutionManager.action(act);
            update();
            game.ui.hud.update();
          };
          actions.appendChild(action);
          n++;
        }

      // add available improvements
      var diff = game.player.evolutionManager.difficulty;
      for (imp in game.player.evolutionManager)
        {
          // limit max level
          var maxLevel = imp.info.maxLevel;
          if (imp.info.id == IMP_BRAIN_PROBE || diff == EASY)
            1;
          else if (diff == NORMAL && maxLevel > 2)
            maxLevel = 2;
          else if (diff == HARD && maxLevel > 1)
            maxLevel = 1;
          if (imp.level >= maxLevel)
            continue;

          var buf = new StringBuf();
          buf.add(n + ': ');
          buf.add("<span style='color:var(--text-color-evolution-title)'>" + imp.info.name + "</span>");
          buf.add(' ');
          buf.add(imp.level + 1);
          buf.add(' (' + imp.ep + '/' +
            EvolutionConst.epCostImprovement[imp.level] + ' ep) (');
          var epLeft = EvolutionConst.epCostImprovement[imp.level] - imp.ep;
          buf.add(Math.round(epLeft / __Math.epPerTurn()));
          buf.add(" turns)<br/>");
          var act: _PlayerAction = {
            id: 'set.' + imp.id,
            type: ACTION_EVOLUTION,
            name: buf.toString(),
            energy: 0,
          };
          listActions.push(act);
          // html element
          var action = Browser.document.createDivElement();
          action.className = 'window-evolution-actions-item';
          action.innerHTML = buf.toString();
          action.onclick = function (e) {
            game.player.evolutionManager.action(act);
            update();
            game.ui.hud.update();
          };
          actions.appendChild(action);
          n++;
        }

      setParams({
        list: listtext,
        info: infotext,
      });
    }

  public override function action(index: Int)
    {
      var a = listActions[index - 1];
      if (a == null)
        return;
      game.player.evolutionManager.action(a);
      update();
      game.ui.hud.update();
    }

  public override function setParams(obj: Dynamic)
    {
      list.innerHTML = obj.list;
      info.innerHTML = obj.info;
//      text.scrollTop = 10000;
    }
}
