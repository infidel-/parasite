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
  var fpsEl: SpanElement;          // FPS readout (left of the gear); shown only when config.vidShowFps
  var fpsFrames: Int = 0;          // frames counted in the current sample window
  var fpsSample: Float = 0;        // rAF timestamp of the current sample window start (0 = fresh)
  var fpsRunning: Bool = false;    // is the rAF meter loop live?
  var lastTurn: Int = -1;          // detects turn advance for odometer tick
  var lastLocName: String = '';    // detects area change for decode + pin ping
  var decodeGen: Int = 0;          // generation token: cancels stale in-flight decode loops
  var settleTimer: haxe.Timer;     // movement-settle: blur smears while moving, decode fires on rest
  static inline var SETTLE_MS = 120; // ms the location must hold before name decodes

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
        '<div class="hud-right"><span class="hud-fps" style="font-family:monospace;font-size:11px;color:var(--dim);align-self:center;margin-right:8px;display:none"></span><div class="hud-gear">' + UISvg.hudGear() + '</div></div>';
      hud.container.appendChild(topbar);
      topbarName = cast topbar.querySelector('.hud-loc-name');
      topbarCoords = cast topbar.querySelector('.hud-loc-coords');
      topbarTurn = cast topbar.querySelector('.hud-turn span');
      topbarPinSvg = topbar.querySelector('.hud-loc svg');
      fpsEl = cast topbar.querySelector('.hud-fps');
      // gear opens options
      (cast topbar.querySelector('.hud-gear') : DivElement).onclick = function (e)
        {
          game.scene.sounds.play('click-hud');
          game.ui.state = UISTATE_MAINMENU;
        };
      ensureFps();
    }

// start the rAF FPS meter if enabled and not already running; sync span visibility.
// called from the constructor, update(), and the Video toggle (immediate response)
  public function ensureFps()
    {
      fpsEl.style.display = (game.config.vidShowFps ? '' : 'none');
      if (game.config.vidShowFps && !fpsRunning)
        {
          fpsRunning = true;
          fpsFrames = 0;
          fpsSample = 0;
          js.Browser.window.requestAnimationFrame(fpsTick);
        }
    }

// per-frame meter: count rAF callbacks, report averaged FPS every ~500ms. self-stops
// (and hides) when config.vidShowFps turns off, so it costs nothing while disabled
  function fpsTick(now: Float)
    {
      if (!game.config.vidShowFps)
        {
          fpsRunning = false;
          fpsEl.style.display = 'none';
          return;
        }
      fpsFrames++;
      if (fpsSample == 0)
        fpsSample = now;
      else if (now - fpsSample >= 500)
        {
          var txt = Math.round(fpsFrames * 1000 / (now - fpsSample)) + ' FPS';
          // in the 3D street view, append the live draw-call / triangle load
          if (game.location == LOCATION_AREA)
            txt += '  ' + render.StreetView.lastCalls + 'dc  ' +
              (Math.round(render.StreetView.lastTris / 100) / 10) + 'k tri';
          fpsEl.textContent = txt;
          fpsFrames = 0;
          fpsSample = now;
        }
      js.Browser.window.requestAnimationFrame(fpsTick);
    }

// update topbar: turn counter (odometer tick), location name (decode) + coords
  public function update()
    {
      ensureFps(); // pick up a config toggle (also (re)starts the meter after a HUD rebuild)
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

      // resolve the named area + coords for the current scope
      var area: AreaGame = null;
      var coords = '';
      if (game.location == LOCATION_AREA)
        {
          area = game.area;
          coords = game.playerArea.x + ',' + game.playerArea.y;
        }
      else if (game.location == LOCATION_REGION)
        {
          area = game.playerRegion.currentArea;
          coords = game.playerRegion.x + ',' + game.playerRegion.y;
        }
      topbarCoords.textContent = coords;

      // split name: plain district prefix + alert-tinted area/sector label
      var district = (area != null ? area.getDistrictLabel() : '');
      var areaLabel = (area != null ? area.getAreaLabel() : '');
      // calm areas keep the normal name color; tint only escalates with alertness
      var color = (area != null ? area.alertColor() : 'gray');
      var alertClass = (color == 'gray' ? '' : 'alert-' + color);
      var fullName = district + areaLabel;

      // area change: pin pings, name resolves out of glyph noise
      if (fullName != lastLocName)
        {
          lastLocName = fullName;
          if (topbarPinSvg != null)
            {
              topbarPinSvg.classList.remove('ping');
              topbarPinSvg.getBoundingClientRect(); // reflow to retrigger
              topbarPinSvg.classList.add('ping');
            }
          blurTo(district, areaLabel, alertClass);
        }
      // same area: refresh the tint live as alertness rises/falls (no re-decode)
      else
        {
          var areaEl = topbarName.querySelector('.loc-area');
          if (areaEl != null)
            areaEl.className = 'loc-area' + (alertClass != '' ? ' ' + alertClass : '');
        }
    }

// fast region travel: show the destination name smeared (motion blur) instantly,
// then decode it once movement settles (no per-tile decode thrash)
  function blurTo(district: String, areaLabel: String, alertClass: String)
    {
      // kill any in-flight decode loop
      decodeGen++;
      // show the real name immediately, blurred — cheap, no glyph loop per tile
      renderLocation(district, areaLabel, alertClass);
      topbarName.classList.add('loc-blur');
      // restart settle timer: a fresh move keeps the blur, only rest triggers decode
      if (settleTimer != null)
        settleTimer.stop();
      settleTimer = haxe.Timer.delay(function ()
        {
          topbarName.classList.remove('loc-blur');
          decodeLocation(district, areaLabel, alertClass);
        }, SETTLE_MS);
    }

// resolve a location name left-to-right out of glyph noise (~.56s), then settle
// into a plain district prefix + alert-tinted area span
  function decodeLocation(district: String, areaLabel: String, alertClass: String)
    {
      var name = district + areaLabel;
      var glyphs = '▒░#@%&╪◊$';
      var frames = 14;
      var frame = 0;
      // invalidate any in-flight decode: fast moves stop overlapping glyph loops
      var gen = ++decodeGen;
      function step()
        {
          if (gen != decodeGen)
            return;
          if (frame > frames)
            {
              renderLocation(district, areaLabel, alertClass);
              return;
            }
          var n = Std.int(name.length * frame / frames);
          var buf = name.substr(0, n);
          for (i in n...name.length)
            buf += glyphs.charAt(Std.random(glyphs.length));
          topbarName.textContent = buf;
          frame++;
          haxe.Timer.delay(step, 40);
        }
      step();
    }

// render the settled name: plain district prefix + alert-tinted area span
  function renderLocation(district: String, areaLabel: String, alertClass: String)
    {
      topbarName.innerHTML =
        '<span class="loc-district">' + StringTools.htmlEscape(district) + '</span>' +
        '<span class="loc-area' + (alertClass != '' ? ' ' + alertClass : '') + '">' +
          StringTools.htmlEscape(areaLabel) + '</span>';
    }
}
