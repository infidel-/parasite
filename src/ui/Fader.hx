package ui;

import js.Browser;

// full-screen black fade overlay, above both game canvases but below the HUD — masks the
// heavy synchronous stalls at area<->region transitions (city geometry build on enter, region
// map generation on exit). a CSS opacity transition driven by cover()/reveal(): cover() fades
// to solid black then fires onOpaque, so the caller runs the stall UNDER black and reveal()s
class Fader
{
  var el:js.html.DivElement;

  public function new()
    {
      var e:js.html.DivElement = cast Browser.document.getElementById('fader');
      if (e == null)
        {
          e = Browser.document.createDivElement();
          e.id = 'fader';
          var s = e.style;
          s.position = 'fixed';
          s.left = '0';
          s.top = '0';
          s.width = '100%';
          s.height = '100%';
          s.background = '#000';
          s.zIndex = '50';          // above #canvas (0) and #streetview (1), below #hud (100)
          s.opacity = '0';
          s.pointerEvents = 'none';
          Browser.document.body.appendChild(e);
        }
      el = e;
    }

// fade to opaque black over ms, then call onOpaque once black is solid (run the stall there).
// a small buffer past ms guarantees the transition has actually finished before the callback
  public function cover(ms:Int, ?onOpaque:Void->Void):Void
    {
      el.style.transition = 'opacity ' + ms + 'ms linear';
      el.style.opacity = '1';
      if (onOpaque != null)
        Browser.window.setTimeout(onOpaque, ms + 20);
    }

// fade back to transparent over ms
  public function reveal(ms:Int):Void
    {
      el.style.transition = 'opacity ' + ms + 'ms linear';
      el.style.opacity = '0';
    }
}
