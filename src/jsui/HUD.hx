// new js ui hud
package jsui;

import js.Browser;
import js.html.TextAreaElement;
import js.html.DivElement;
import js.html.KeyboardEvent;

import game.*;

class HUD
{
  var game: Game;
  var ui: UI;
  var container: DivElement;
  var consoleDiv: DivElement;
  var console: TextAreaElement;
  var log: DivElement;
  var goals: DivElement;
  var info: DivElement;

  public function new(u: UI, g: Game)
    {
      game = g;
      ui = u;
      container = Browser.document.createDivElement();
      container.id = 'hud';
      container.style.visibility = 'visible';
      Browser.document.body.appendChild(container);

      consoleDiv = Browser.document.createDivElement();
      consoleDiv.className = 'console-div';
      consoleDiv.style.visibility = 'hidden';
      container.appendChild(consoleDiv);

      console = Browser.document.createTextAreaElement();
      console.id = 'hud-console';
      console.onkeydown = function(e: KeyboardEvent) {
        if (e.code == 'Escape')
          hideConsole();
        else if (e.code == 'Enter')
          {
            game.console.run(console.value);
            hideConsole();
          }
      }
      consoleDiv.appendChild(console);

      log = Browser.document.createDivElement();
      log.className = 'text';
      log.id = 'hud-log';
      log.style.borderImage = "url('./img/log-border.png') 15 fill / 1 / 0 stretch";
      container.appendChild(log);

      goals = Browser.document.createDivElement();
      goals.className = 'text';
      goals.id = 'hud-goals';
      goals.style.borderImage = "url('./img/goals-border.png') 24 fill / 1 / 0 stretch";
      container.appendChild(goals);

      info = Browser.document.createDivElement();
      info.className = 'text';
      info.id = 'hud-info';
      info.style.borderImage = "url('./img/info-border.png') 28 fill / 1 / 0 stretch";
      container.appendChild(info);
    }

// show hide HUD
  public inline function toggle()
    {
      container.style.visibility =
        (container.style.visibility == 'visible' ? 'hidden' : 'visible');
    }

  public function consoleVisible(): Bool
    {
      return (consoleDiv.style.visibility == 'visible');
    }

  public function showConsole()
    {
      consoleDiv.style.visibility = 'visible';
      console.value = '';
      Browser.window.setTimeout(function () {
        console.value = '';
      });
      console.focus();
    }

  public function hideConsole()
    {
      consoleDiv.style.visibility = 'hidden';
      ui.focus();
    }

// update HUD state from game state
  public function update()
    {
/*
      updateActionList();
      // NOTE: before info because info uses its height
      updateActions();*/
      updateInfo();
      updateLog();
/*
      updateMenu();
      updateConsole();*/
      updateGoals();
    }

// update log display
  public function updateLog()
    {
      var buf = new StringBuf();
      for (l in game.hudMessageList)
        {
          buf.add("<font color='");
          buf.add(Const.TEXT_COLORS[l.col]);
          buf.add("'>");
          buf.add(l.msg);
          buf.add("</font>");
          if (l.cnt > 1)
            {
              buf.add(" <font color='");
              buf.add(Const.TEXT_COLORS[_TextColor.COLOR_REPEAT]);
              buf.add("'>(x");
              buf.add(l.cnt);
              buf.add(")</font>");
            }
          buf.add('<br/>');
        }

      log.innerHTML = buf.toString();
    }

// update goals list
  function updateGoals()
    {
      var buf = new StringBuf();

      for (g in game.goals.iteratorCurrent())
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add("<font color='" +
            Const.TEXT_COLORS[_TextColor.COLOR_GOAL] +
            "'>" + info.name + '</font><br/>');
          buf.add(info.note + '<br/>');
          if (info.note2 != null)
            buf.add(info.note2 + '<br/>');
          buf.add('<br/>');
        }
      var s = buf.toString().substr(0, buf.length - 10); // remove last two br's'

      goals.innerHTML = s;
    }

// get color for text (red, yellow, white)
  function getTextColor(val: Float, max: Float)
    {
      if (val > 0.7 * max)
        return '#FFFFFF';
      else if (val > 0.3 * max)
        return '#FFEA0E';

      return '#FC420E';
    }

// update player info
  function updateInfo()
    {
      var buf = new StringBuf();
      buf.add('Turn: ' + game.turns + ', at (');
      if (game.location == LOCATION_AREA)
          buf.add(
            game.playerArea.x + ',' + game.playerArea.y + ')' +
#if mydebug
            ' A ' + Math.round(game.area.alertness) +
#end
            '<br/>Actions: ' + game.playerArea.ap + '<br/>');
      else if (game.location == LOCATION_REGION)
        buf.add(
          game.playerRegion.x + ',' + game.playerRegion.y + ')' +
#if mydebug
            ' A ' + Math.round(game.playerRegion.currentArea.alertness) +
#end
          '<br/>' + game.playerRegion.currentArea.name + '<br/>');
      buf.add('===<br/>');

      var colEnergy = getTextColor(game.player.energy, game.player.maxEnergy);
      var time = (game.location == LOCATION_AREA ? 1 : 5);
      var energyPerTurn = __Math.parasiteEnergyPerTurn(time);
      buf.add('Energy: ' +
        "<font color='" + colEnergy + "'>" + game.player.energy + "</font>" +
        '/' + game.player.maxEnergy);
      buf.add(' [' + (energyPerTurn > 0 ? '+' : '') + energyPerTurn + '/t]<br/>');
      var colHealth = getTextColor(game.player.health, game.player.maxHealth);
      buf.add('Health: ' +
        "<font color='" + colHealth + "'>" + game.player.health + "</font>" +
        '/' + game.player.maxHealth);

      if (game.player.state == PLR_STATE_ATTACHED)
        {
          buf.add('<br/>===<br/>');
          buf.add("Grip: <font color='" +
            getTextColor(game.playerArea.attachHold, 100) + "'>" +
            game.playerArea.attachHold + "</font>/100<br/>");
        }

      // host stats
      else if (game.player.state == PLR_STATE_HOST)
        {
          buf.add('<br/>===<br/>');
          buf.add(game.player.host.getNameCapped());
          if (game.player.host.isJobKnown)
            buf.add(' (' + game.player.host.job + ')<br/>');
          else buf.add('<br/>');
          if (game.player.host.isAttrsKnown)
            buf.add('STR ' + game.player.host.strength +
              ' CON ' + game.player.host.constitution +
              ' INT ' + game.player.host.intellect +
              ' PSY ' + game.player.host.psyche + '<br/>');

          var colHealth = getTextColor(game.player.host.health,
            game.player.host.maxHealth);
          buf.add('Health: ' +
            "<font color='" + colHealth + "'>" + game.player.host.health + "</font>" +
            '/' + game.player.host.maxHealth + '<br/>');

          var colControl = getTextColor(game.player.hostControl, 100);
          buf.add('Control: ' +
            "<font color='" + colControl + "'>" + game.player.hostControl + "</font>" +
            '/100<br/>');

          var colEnergy = getTextColor(game.player.host.energy,
            game.player.host.maxEnergy);
          var energyPerTurn = __Math.fullHostEnergyPerTurn(time);
          buf.add("Energy: <font color='" + colEnergy + "'>" +
            game.player.host.energy + '</font>/' +
            game.player.host.maxEnergy);
          buf.add(' [' + (energyPerTurn > 0 ? '+' : '') +
            energyPerTurn + '/t]<br/>');
          buf.add('Evolution direction:<br/>  ');
          buf.add(game.player.evolutionManager.getEvolutionDirectionInfo());
          var str = game.player.host.organs.getInfo();
          if (str != null)
            {
              buf.add('<br/>');
              buf.add(str);
            }
        }

      info.innerHTML = buf.toString();
    }
}

