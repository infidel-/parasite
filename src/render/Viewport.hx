// cached viewport size in css px. reading document.body.clientWidth / window.innerWidth forces a
// synchronous layout reflow whenever layout is dirty — and the per-frame hud (chat bubbles, offscreen
// icons, chat convo) each read it once per element, after the previous frame's style writes had
// dirtied layout, so every read triggered a full reflow. the viewport only changes on window resize,
// so read it there and let the hot path read plain fields
package render;

import js.Browser;

class Viewport
{
  public static var w = 0.0;      // viewport width in css px
  public static var h = 0.0;      // viewport height in css px
  static var inited = false;

// install the resize listener and take the first reading; idempotent, so every consumer can call it
// from its constructor without caring about order
  public static function init():Void
    {
      if (inited)
        return;
      inited = true;
      refresh();
      Browser.window.addEventListener('resize', function(_) refresh());
    }

// re-read the viewport size — the only place that forces a reflow, and it runs only on resize
  public static function refresh():Void
    {
      w = Browser.window.innerWidth;
      h = Browser.window.innerHeight;
    }
}
