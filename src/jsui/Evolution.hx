// evolution GUI window

package jsui;

import js.Browser;
import js.html.DivElement;
import js.html.ImageElement;

import game.Game;
import game.Improv;
import const.EvolutionConst;

class Evolution extends UIWindow
{
  var list: DivElement;
  var info: DivElement;
  var img: ImageElement;
  var actions: DivElement;
  var listActions: Array<_PlayerAction>;

  public function new(g: Game)
    {
      super(g, 'window-evolution');
      listActions = [];
      window.style.borderImage = "url('./img/window-evolution.png') 210 fill / 1 / 0 stretch";

      var cont = Browser.document.createDivElement();
      cont.id = 'window-evolution-contents';
      window.appendChild(cont);
      var bottom = Browser.document.createDivElement();
      bottom.id = 'window-evolution-bottom';
      var bottomLeft = Browser.document.createDivElement();
      bottomLeft.id = 'window-evolution-bottom-left';
      bottom.appendChild(bottomLeft);
      var bottomRight = Browser.document.createDivElement();
      bottomRight.id = 'window-evolution-bottom-right';
      bottom.appendChild(bottomRight);

      list = addBlock(cont, 'window-evolution-list', 'CONTROLLED EVOLUTION: IMPROVEMENTS');
      cont.appendChild(bottom);
      info = addBlock(bottomLeft, 'window-evolution-info', 'INFO', 'scroller small');
      actions = addBlock(bottomLeft, 'window-evolution-actions', 'ACTIONS');
      img = Browser.document.createImageElement();
      img.className = 'message-img';
      img.id = 'window-evolution-img';
      bottomRight.appendChild(img);
      addCloseButton();
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
        buf.add(' &rarr; ' + (imp.level + 1));
      if (imp.level < imp.info.maxLevel)
        buf.add(' (' + imp.ep + '/' +
          EvolutionConst.epCostImprovement[imp.level] + ' ep)');
      if (imp.isLocked)
        buf.add(' ' + Icon.checkbox);
      buf.add("<p class=small style='color:var(--text-color-evolution-note);margin: 0px;'>" + imp.info.note + '</p>');

      // imp notes
      buf.add('<p class=window-evolution-list-notes>');
      var levelNote = imp.info.levelNotes[imp.level];
      var nextLevelNote = '';
      if (!isMaxLevel)
        nextLevelNote = ' &rarr; ' + imp.info.levelNotes[imp.level + 1];
      if (levelNote.indexOf('fluff') < 0 &&
          levelNote.indexOf('todo') < 0 &&
          levelNote != '')
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
      buf.add('<span class=gray>');
      if (game.location == LOCATION_AREA &&
          game.area.isHabitat)
        buf.add('You are in a microhabitat.<br/>');
      buf.add('Evolving costs additional ' + __Math.evolutionEnergyPerTurn() +
        ' energy per turn.<br/>' +
        'You will receive ' + __Math.epPerTurn() + ' ep per turn.<br/>' +
        'Your host will survive for ' +
          Std.int(game.player.host.energy / __Math.evolutionEnergyPerTurn()) +
        ' turns while evolving (not counting other spending).<br/>');
      buf.add('</span>');
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
          action.className = 'actions-item';
          action.innerHTML = Const.key('' + n) + ': Stop evolution';
          action.onclick = function (e) {
            game.scene.sounds.play('click-action');
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
          buf.add(Const.key('' + n) + ': ');
          buf.add("<span style='color:var(--text-color-evolution-title)'>" + imp.info.name + "</span>");
          buf.add(' ');
          buf.add(imp.level + 1);
          buf.add(' (' + imp.ep + '/' +
            EvolutionConst.epCostImprovement[imp.level] + ' ep) ');
          buf.add('<span class=gray>(');
          var epLeft = EvolutionConst.epCostImprovement[imp.level] - imp.ep;
          buf.add(Math.round(epLeft / __Math.epPerTurn()));
          buf.add(" turns)</span><br/>");
          var act: _PlayerAction = {
            id: 'set.' + imp.id,
            type: ACTION_EVOLUTION,
            name: buf.toString(),
            energy: 0,
          };
          listActions.push(act);
          // html element
          var action = Browser.document.createDivElement();
          action.className = 'actions-item';
          action.innerHTML = buf.toString();
          action.onclick = function (e) {
            game.scene.sounds.play('click-action');
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
      updateImage();
    }

// update current improvement image
  function updateImage()
    {
      img.style.animation = 'none';
      img.src = './img/black.jpg';
      Browser.window.setTimeout(function() {
        if (game.player.evolutionManager.isActive)
          img.src = './img/imp/' + game.player.evolutionManager.taskID + '.jpg';
        else img.src = './img/imp/imp_none.jpg';
        img.style.animation = '';
      }, 10);
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
