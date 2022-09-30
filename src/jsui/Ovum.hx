// ovum settings GUI window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;
import game.Improv;
import game.EvolutionManager;
import const.EvolutionConst;

class Ovum extends UIWindow
{
  var list: DivElement;
  var info: DivElement;
  var actions: DivElement;
  var listActions: Array<_PlayerAction>;

  public function new(g: Game)
    {
      super(g, 'window-ovum');
      listActions = [];
      window.style.borderImage = "url('./img/window-evolution.png') 210 fill / 1 / 0 stretch";

      var cont = Browser.document.createDivElement();
      cont.id = 'window-evolution-contents';
      window.appendChild(cont);
      list = addBlock(cont, 'window-evolution-list', 'PARTHENOGENESIS: IMPROVEMENTS');
      info = addBlock(cont, 'window-evolution-info', 'INFO');
      actions = addBlock(cont, 'window-evolution-actions', 'ACTIONS');
      addCloseButton();
    }

// add improvement (col 0 or 1)
  function addImp(buf: StringBuf, imp: Improv, isCol0: Bool)
    {
      if (isCol0)
        buf.add('<div class=window-evolution-list-row>');

      // title line
      buf.add('<div class=window-evolution-list-item>');
      buf.add("<span style='color:var(--text-color-evolution-title)'>" + imp.info.name + "</span>");
      buf.add(' ');
      if (imp.info.maxLevel > 1)
        buf.add(imp.level);
      if (imp.isLocked)
        buf.add('&#9745;');
      buf.add("<p class=small style='color:var(--text-color-evolution-note);margin: 0px;'>" + imp.info.note + '</p>');

      // imp notes
      buf.add('<p class=window-evolution-list-notes>');
      var levelNote = imp.info.levelNotes[imp.level];
      var nextLevelNote = '';
      if (levelNote.indexOf('fluff') < 0 &&
          levelNote.indexOf('todo') < 0 &&
          levelNote != '')
        buf.add("<span style='color:var(--text-color-evolution-level-note)'>" + levelNote + '</span><br/>');
/*
      if (imp.info.noteFunc != null)
        buf.add("<span style='color:var(--text-color-evolution-params)'>" +
          imp.info.noteFunc(imp.info.levelParams[imp.level],
            (isMaxLevel ? null : imp.info.levelParams[imp.level + 1])) + '</span><br/>');
*/
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
      var cntLocked = 0;
      for (imp in game.player.evolutionManager)
        {
          // only basic improvements
          if (imp.info.type != TYPE_BASIC)
            continue;
          addImp(buf, imp, (n % 2 == 0));
          n++;
          if (imp.isLocked)
            cntLocked++;
        }
      if (n == 0)
        buf.add('  --- empty ---<br/>');
      var listtext = buf.toString();

      // info block
      var buf = new StringBuf();
      var ovum = game.player.evolutionManager.ovum;
      buf.add(cntLocked + '/' + ovum.level + ' improvements marked for parthenogenesis.');
      var infotext = buf.toString();

      // actions
      listActions = [];
      actions.innerHTML = '';
      var n = 1;
      // add available improvements
      for (imp in game.player.evolutionManager)
        {
          // only basic improvements
          if (imp.info.type != TYPE_BASIC)
            continue;
          // limit reached
          if (!imp.isLocked && cntLocked >= ovum.level)
            continue;

          var buf = new StringBuf();
          buf.add(Const.key('' + n) + ': ');
          buf.add(imp.isLocked ? 'Unlock ' : 'Lock ');
          buf.add("<span style='color:var(--text-color-evolution-title)'>" + imp.info.name + "</span>");
          buf.add(' ');
          buf.add(imp.level);
//          buf.add("<br/>");
          var act: _PlayerAction = {
            id: 'toggle.' + imp.id,
            type: ACTION_UI,
            name: buf.toString(),
            energy: 0,
            obj: imp,
          };
          listActions.push(act);
          // html element
          var action = Browser.document.createDivElement();
          action.className = 'actions-item';
          action.innerHTML = buf.toString();
          action.onclick = function (e) {
            runAction(act);
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
      runAction(a);
    }

  function runAction(a: _PlayerAction)
    {
      var imp: Improv = a.obj;
      imp.isLocked = !imp.isLocked;
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
