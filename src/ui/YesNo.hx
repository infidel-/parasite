// yes/no confirm dialog (glyph + kicker + prompt + sub; neutral or danger)

package ui;

import js.Browser;
import js.html.DivElement;
import js.html.Element;

import game.Game;

class YesNo extends UIWindow
{
  var kickerEl: Element;
  var textEl: Element;
  var subEl: Element;
  var func: Bool -> Void;
  var backState: _UIState; // state to return to on close (DEFAULT unless opened over another window)

  public function new(g: Game)
    {
      super(g, 'window-yesno');
      window.className += ' window-confirm';

      // corner brackets (shared redesign chrome)
      addCorners();

      // glyph in its accent ring (ask glyph default, warn when .danger)
      var glyph = Browser.document.createDivElement();
      glyph.className = 'yesno-glyph';
      glyph.innerHTML = UISvg.confirmGlyphs();
      window.appendChild(glyph);

      // kicker / prompt / sub-detail
      kickerEl = Browser.document.createDivElement();
      kickerEl.className = 'yesno-kicker';
      window.appendChild(kickerEl);
      textEl = Browser.document.createDivElement();
      textEl.className = 'yesno-text';
      window.appendChild(textEl);
      subEl = Browser.document.createDivElement();
      subEl.className = 'yesno-sub';
      window.appendChild(subEl);

      // actions: NO (neutral) then YES (accent)
      var actions = Browser.document.createDivElement();
      actions.className = 'yesno-actions';
      window.appendChild(actions);

      var yes = Browser.document.createDivElement();
      yes.className = 'yesno-btn yesno-yes';
      yes.id = 'window-yesno-yes';
      yes.innerHTML = 'YES';
      yes.onclick = function (e) {
        func(true);
        game.scene.sounds.play('click-menu');
        dismiss();
      }
      actions.appendChild(yes);

      var no = Browser.document.createDivElement();
      no.className = 'yesno-btn yesno-no';
      no.id = 'window-yesno-no';
      no.innerHTML = 'NO';
      no.onclick = function (e) {
        func(false);
        game.scene.sounds.play('click-menu');
        dismiss();
      }
      actions.appendChild(no);
    }

// set parameters: text + handler, optional sub-detail / danger / kicker override
  public override function setParams(obj: Dynamic)
    {
      // trust boundary: event payload is untyped, assembled ad-hoc at call sites
      var o: { text: String, func: Bool -> Void, ?sub: String, ?danger: Bool, ?kicker: String, ?back: _UIState } = cast obj;
      func = o.func;
      backState = (o.back != null ? o.back : UISTATE_DEFAULT);
      var danger = (o.danger == true);
      window.classList.toggle('danger', danger);
      kickerEl.innerHTML = (o.kicker != null ? o.kicker : (danger ? 'Confirm exit' : 'Confirm'));
      textEl.innerHTML = o.text;
      subEl.innerHTML = (o.sub != null ? o.sub : '');
      subEl.style.display = (o.sub != null ? '' : 'none');
    }

// close: return to the opener state (DEFAULT drains the event queue; otherwise reopen that window)
  function dismiss()
    {
      if (backState != UISTATE_DEFAULT)
        game.ui.state = backState;
      else game.ui.closeWindow();
    }

// action
  public override function action(index: Int)
    {
      func(index == 1);
      dismiss();
    }

// dom button for a 1-based index (1 = yes, 2 = no), so keyboard clicks/animates it
  public override function getButton(index: Int): js.html.Element
    {
      return Browser.document.getElementById(index == 1 ? 'window-yesno-yes' : 'window-yesno-no');
    }
}
