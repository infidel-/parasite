// hud topbar block: location (pin + name + coords), turn counter, gear
package ui.hud;

import js.Browser.document;
import js.html.DivElement;
import js.html.SpanElement;
import js.html.Element;

import game.*;

class TopbarHud
{
  var game: Game;
  var hud: HUD;
  var topbar: DivElement;
  var topbarName: SpanElement;
  var topbarCoords: DivElement;
  var topbarTurn: SpanElement;
  var topbarPinSvg: Element;
  var lastTurn: Int = -1;          // detects turn advance for odometer tick
  var lastLocName: String = '';    // detects area change for decode + pin ping

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;
      // topbar: location (pin + name + coords), turn counter, gear
      topbar = document.createDivElement();
      topbar.id = 'hud-topbar';
      topbar.innerHTML =
        '<div class="hud-loc">' + UISvg.hudPin() +
          '<div><div class="hud-loc-name"></div><div class="hud-loc-coords"></div></div></div>' +
        '<div class="hud-turn">' + UISvg.clockSmall('hud-ico-time') + '<span></span></div>' +
        '<div class="hud-right"><div class="hud-gear">' + UISvg.hudGear() + '</div></div>';
      hud.container.appendChild(topbar);
      topbarName = cast topbar.querySelector('.hud-loc-name');
      topbarCoords = cast topbar.querySelector('.hud-loc-coords');
      topbarTurn = cast topbar.querySelector('.hud-turn span');
      topbarPinSvg = topbar.querySelector('.hud-loc svg');
      // gear opens options
      (cast topbar.querySelector('.hud-gear') : DivElement).onclick = function (e)
        {
          game.scene.sounds.play('click-hud');
          game.ui.state = UISTATE_MAINMENU;
        };
    }

// update topbar: turn counter (odometer tick), location name (decode) + coords
  public function update()
    {
      // turn advance: number rolls over, brackets/word flash (css via .tick)
      if (game.turns != lastTurn)
        {
          if (lastTurn >= 0)
            {
              topbarTurn.className = 'tick';
              var nv = game.turns;
              haxe.Timer.delay(function () topbarTurn.textContent = '' + nv, 140);
              haxe.Timer.delay(function () topbarTurn.className = '', 400);
            }
          else topbarTurn.textContent = '' + game.turns;
          lastTurn = game.turns;
        }

      // location name + coords from current scope
      var name = '';
      var coords = '';
      if (game.location == LOCATION_AREA)
        {
          name = game.area.name;
          coords = game.playerArea.x + ',' + game.playerArea.y;
        }
      else if (game.location == LOCATION_REGION)
        {
          name = game.playerRegion.currentArea.name;
          coords = game.playerRegion.x + ',' + game.playerRegion.y;
        }
      if (name == null)
        name = '';
      topbarCoords.textContent = coords;

      // area change: pin pings, name resolves out of glyph noise
      if (name != lastLocName)
        {
          lastLocName = name;
          if (topbarPinSvg != null)
            {
              topbarPinSvg.classList.remove('ping');
              topbarPinSvg.getBoundingClientRect(); // reflow to retrigger
              topbarPinSvg.classList.add('ping');
            }
          decodeLocation(name);
        }
    }

// resolve a location name left-to-right out of glyph noise (~.56s)
  function decodeLocation(name: String)
    {
      var glyphs = '▒░#@%&╪◊$';
      var frames = 14;
      var frame = 0;
      function step()
        {
          var n = Std.int(name.length * frame / frames);
          var buf = name.substr(0, n);
          for (i in n...name.length)
            buf += glyphs.charAt(Std.random(glyphs.length));
          topbarName.textContent = buf;
          frame++;
          if (frame <= frames)
            haxe.Timer.delay(step, 40);
          else topbarName.textContent = name;
        }
      step();
    }
}
