// cult stats/actions GUI window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Cult extends UIWindow
{
  var info: DivElement;
  var actions: DivElement;
  var listActions: Array<_PlayerAction>;

  public function new(g: Game)
    {
      super(g, 'window-cult');
      listActions = [];
      window.style.borderImage = "url('./img/window-evolution.png') 210 fill / 1 / 0 stretch";

      var cont = Browser.document.createDivElement();
      cont.id = 'window-cult-contents';
      window.appendChild(cont);

      info = addBlock(cont, 'window-cult-info', 'INFO', 'scroller');
      actions = addBlock(cont, 'window-cult-actions', 'ACTIONS');
      addCloseButton();
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
      buf.add(Const.col('cult-power-title', 'MONEY') + ' ' + cult.resources.money);
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

      // actions
      listActions = [];
      actions.innerHTML = '';

      // action - call for help
      var n = 1;
      if (cult.canCallHelp())
        {
          var act: _PlayerAction = {
            id: 'callHelp',
            type: ACTION_CULT,
            name: 'Call for help',
            energy: 0,
          };
          listActions.push(act);
          var action = Browser.document.createDivElement();
          action.className = 'actions-item';
          action.innerHTML = Const.key('' + n) + ': Call for help';
          action.onclick = function (e) {
            game.scene.sounds.play('click-action');
            game.cults[0].action(act);
    /*
          update();
          game.ui.hud.update();*/
            game.ui.closeWindow();
          };
          actions.appendChild(action);
          n++;
        }

      setParams({
        info: infotext,
      });
    }

  public override function action(index: Int)
    {
      var a = listActions[index - 1];
      if (a == null)
        return;
      game.cults[0].action(a);
/*
      update();
      game.ui.hud.update();*/
      game.ui.closeWindow();
    }

  public override function setParams(obj: Dynamic)
    {
      info.innerHTML = obj.info;
//      text.scrollTop = 10000;
    }
}
