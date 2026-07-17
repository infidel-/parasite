// hud chat-bubble block: speech bubbles anchored above a speaker's head in the 3D street view,
// with a tail pointing back down at them. pooled DOM divs under #hud (so the Space HUD-toggle
// hides them), driven per-frame from render.Actors.
// deliberately speaker-agnostic — it takes text + font + variant + screen px, never an AI — so the
// chat conversation minigame can drive the same surface
package ui.hud;

import js.Browser.document;
import js.html.DivElement;

import game.Game;

// one live bubble: its element plus the text identity it was built for
typedef Bubble = {
  el: DivElement,       // the div; kept across frames so its css appear anim is not restarted
  id: Int,              // the speaker's textID this bubble was built for
  seen: Bool,           // touched by show() this frame?
  dying: Bool,          // playing the exit anim (its detach timer is armed)
};

class ChatBubbles
{
  var game: Game;
  var hud: HUD;
  var container: DivElement;
  var live: Map<String, Bubble> = new Map();

  static inline var MARGIN = 8;       // min px from the screen sides
  static inline var TAIL_INSET = 16;  // tail stays this far from the bubble's own corners
  static inline var OUT_MS = 260;     // exit anim length — keep in sync with bubble-out in app.css

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;
      container = document.createDivElement();
      container.id = 'chat-bubbles';
      hud.container.appendChild(container);
    }

// start a frame: nothing is touched yet
  public function begin():Void
    {
      for (b in live)
        b.seen = false;
    }

// queue one bubble this frame: a caller-scoped speaker key, the speaker's text identity (a change
// replays the appear anim), the already lang-rendered text + its css font-family, the variant class
// ('say' | 'bark' | 'shout') and the anchor point in client px. the bubble sits above the anchor
// with its tail on it; when it clamps against a screen side the tail slides to keep pointing at the
// speaker instead of lying
  public function show(key: String, id: Int, text: String, fontFamily: String, kind: String,
      x: Float, y: Float):Void
    {
      var b = live.get(key);
      if (b == null)
        {
          var el = document.createDivElement();
          container.appendChild(el);
          b = {
            el: el,
            id: -1,
            seen: true,
            dying: false,
          };
          live.set(key, b);
        }
      b.seen = true;
      // a new bark, or this one re-entering mid-exit: rebuild and replay the appear anim
      if (b.id != id ||
          b.dying)
        {
          b.id = id;
          b.dying = false; // disarms the in-flight exit timer (it re-checks this)
          setText(b.el, text);
          b.el.style.fontFamily = fontFamily;
          b.el.className = 'chat-bubble ' + kind; // also drops any leftover .out
          untyped b.el.offsetWidth;               // reflow, so a replay restarts from frame 0
          b.el.classList.add('in');
        }

      // clamp the bubble inside the screen, then point the tail back at the anchor. the div is
      // translated (-50%, -100%) from its left/top, so left = the bubble's horizontal centre and
      // top = where the tail tip lands
      var vw = document.body.clientWidth;
      var vh = document.body.clientHeight;
      var half = b.el.offsetWidth / 2;
      var cx = x;
      if (cx - half < MARGIN)
        cx = MARGIN + half;
      if (cx + half > vw - MARGIN)
        cx = vw - MARGIN - half;
      var cy = y;
      if (cy - b.el.offsetHeight < MARGIN)
        cy = MARGIN + b.el.offsetHeight;
      if (cy > vh - MARGIN)
        cy = vh - MARGIN;
      var tail = x - (cx - half);
      if (tail < TAIL_INSET)
        tail = TAIL_INSET;
      if (tail > half * 2 - TAIL_INSET)
        tail = half * 2 - TAIL_INSET;
      b.el.style.left = cx + 'px';
      b.el.style.top = cy + 'px';
      b.el.style.setProperty('--tail-x', tail + 'px');
    }

// fills a bubble with its line, splitting the noises out from the words: a noise is wrapped in
// asterisks (*GROWL*, *choke*) and renders gray, spoken words render in the normal text color, so a
// line carrying both reads as two separate things. built as text nodes rather than innerHTML — the
// line is already lang-rendered gibberish and has no business going through an html parser
  function setText(el: DivElement, text: String):Void
    {
      el.textContent = '';
      // asterisk runs on both sides, so a bare '***' is one noise rather than a stray leftover
      var re = ~/\*+[^*]*\*+/g;
      var at = 0;
      while (re.matchSub(text, at))
        {
          var p = re.matchedPos();
          if (p.pos > at)
            el.appendChild(document.createTextNode(text.substring(at, p.pos)));
          var noise = document.createSpanElement();
          noise.className = 'chat-noise';
          noise.textContent = re.matched(0);
          el.appendChild(noise);
          at = p.pos + p.len;
        }
      if (at < text.length)
        el.appendChild(document.createTextNode(text.substr(at)));
    }

// end a frame: retire every bubble nothing touched this frame (its turn timer expired, or the
// speaker died / walked out of LOS) — play the exit anim, then detach
  public function end():Void
    {
      for (key in live.keys())
        {
          var b = live.get(key);
          if (b.seen ||
              b.dying)
            continue;
          b.dying = true;
          b.el.classList.remove('in');
          b.el.classList.add('out');
          haxe.Timer.delay(function()
            {
              // it came back mid-exit (or the view tore down): show()/clear() own the element now
              if (!b.dying)
                return;
              container.removeChild(b.el);
              live.remove(key);
            }, OUT_MS);
        }
    }

// drop every bubble at once (street view teardown; the block itself lives as long as the HUD)
  public function clear():Void
    {
      for (b in live)
        {
          b.dying = false; // disarm any in-flight exit timer before its element goes away
          container.removeChild(b.el);
        }
      live.clear();
    }
}
