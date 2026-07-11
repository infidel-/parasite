// hud off-screen AI block: screen-edge indicators for AI the player sees (game LOS) but the
// 3D camera crops out of frame: the AI's alert badge glyph inside a circle, both tinted by the
// alert-rating color (same ramp as the 3D outlines/badges, see Badges.outlineColor). pooled DOM
// divs under #hud (so the Space HUD-toggle hides them), driven per-frame from render.Actors
package ui.hud;

import js.Browser.document;
import js.html.DivElement;

import game.Game;

class OffscreenHud
{
  var game: Game;
  var hud: HUD;
  var container: DivElement;
  var pool: Array<DivElement> = [];
  var keys: Array<String> = [];                           // cached glyph key per pooled div (skip innerHTML rewrites)
  var used = 0;

  static inline var MARGIN = 24;                          // min px from the screen sides

// calm AI (no alert badge) show a plain center dot inside the circle
  static inline var CALM_DOT = '<svg viewBox="0 0 24 24" aria-hidden="true">' +
    '<circle cx="12" cy="12" r="3.4" fill="currentColor"/></svg>';

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;
      container = document.createDivElement();
      container.id = 'offscreen-ai';
      hud.container.appendChild(container);
    }

// start a frame: reset the pool cursor
  public function begin():Void
    {
      used = 0;
    }

// queue one indicator this frame: badge glyph key ('' = calm, dot in circle), css color, the
// AI's NDC point (caller pre-flips behind-camera projections), and the badge pulse scale (see
// Badges.pulseScale); pinned to the nearest screen edge along the ray from the screen center,
// clamped inside the margins
  public function show(key:String, color:String, ndcX:Float, ndcY:Float, scale:Float):Void
    {
      var el:DivElement;
      if (used < pool.length)
        el = pool[used];
      else
        {
          el = document.createDivElement();
          el.className = 'offscreen-ai-icon';
          container.appendChild(el);
          pool.push(el);
          keys.push(null);
        }
      if (keys[used] != key)
        {
          el.innerHTML = (key == '' ? CALM_DOT : UISvg.badge(key));
          keys[used] = key;
        }
      el.style.color = color;
      // scale the NDC point along the center ray onto the [-1,1] box edge
      var m = Math.max(Math.abs(ndcX), Math.abs(ndcY));
      if (m < 1e-6)
        m = 1e-6;
      var w = document.body.clientWidth;
      var h = document.body.clientHeight;
      var x = (ndcX / m * 0.5 + 0.5) * w;
      var y = (-ndcY / m * 0.5 + 0.5) * h;
      if (x < MARGIN)
        x = MARGIN;
      if (x > w - MARGIN)
        x = w - MARGIN;
      if (y < MARGIN)
        y = MARGIN;
      if (y > h - MARGIN)
        y = h - MARGIN;
      el.style.left = x + 'px';
      el.style.top = y + 'px';
      el.style.transform = (scale == 1 ? '' : 'scale(' + scale + ')');
      el.style.display = 'flex';
      used++;
    }

// end a frame: hide leftover pooled divs
  public function end():Void
    {
      for (i in used...pool.length)
        pool[i].style.display = 'none';
    }

// hide all indicators (street view teardown; the block itself lives as long as the HUD)
  public function clear():Void
    {
      used = 0;
      end();
    }
}
