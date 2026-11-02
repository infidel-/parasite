// main menu changelog: button on the card's lower right corner + glass panel right of the card, built from changes.md

package ui;

import js.Browser;
import js.html.DivElement;
import js.html.Element;

import game.Game;

class MainMenuChangelog
{
  static inline var GAP = 32; // px of margin around the panel (half on each side when space is tight)
  static inline var CARD_GAP = 16; // px between the card and the panel
  static inline var MAX_WIDTH = 420; // px panel width cap
  static inline var MIN_WIDTH = 200; // px panel width floor (may overlap the card in a tiny window)

  var game: Game;
  var card: Element; // main menu card the panel matches in height
  var button: DivElement;
  var panel: DivElement;

  public function new(g: Game, bg: Element, card: Element)
    {
      game = g;
      this.card = card;

      // button straddling the card's bottom edge at its right corner
      button = Browser.document.createDivElement();
      button.className = 'mm-cl-btn';
      button.innerHTML =
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">' +
        '<line x1="9" y1="7" x2="20" y2="7"/><line x1="9" y1="12" x2="20" y2="12"/><line x1="9" y1="17" x2="16" y2="17"/>' +
        '<circle cx="4.5" cy="7" r="1.2"/><circle cx="4.5" cy="12" r="1.2"/><circle cx="4.5" cy="17" r="1.2"/></svg>' +
        '<span>' + T('CHANGELOG') + '</span>';
      // glowing dot until this version's changelog is opened
      button.classList.toggle('new', game.profile.object.changelogSeen != Version.getVersion());
      button.onclick = function(e) {
        game.scene.sounds.play('click-menu');
        toggle();
      };
      card.appendChild(button);

      // panel: header + scrolling version list
      panel = Browser.document.createDivElement();
      panel.className = 'mm-cl';
      panel.innerHTML = UISvg.corners() +
        '<div class="mm-cl-head"><span class="mm-cl-title">' + T('CHANGELOG') + '</span></div>' +
        '<div class="mm-cl-body">' + render(Version.getChangelog()) + '</div>';
      bg.appendChild(panel);

      // corner-X close, the shared .win-x look (turns and glows on hover)
      var x = Browser.document.createDivElement();
      x.className = 'win-x';
      x.innerHTML =
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">' +
        '<line x1="6" y1="6" x2="18" y2="18"/><line x1="18" y1="6" x2="6" y2="18"/></svg>' +
        '<span class="esc">' + T('ESC') + '</span>';
      x.onclick = function(e) {
        game.scene.sounds.play('click-menu');
        close();
      };
      panel.appendChild(x);

      Browser.window.addEventListener('resize', function(e) {
        if (isOpen())
          place();
      });
    }

// changes.md to html: "## version", "### section" (shown only once it has entries), "- tag: entry".
// flat children of one two-column grid, so every tag chip in the log shares one column width
  static function render(md: String): String
    {
      var current = Version.getVersion();
      var out = new StringBuf();
      var section: String = null; // pending section heading
      for (raw in md.split('\n'))
        {
          var line = StringTools.trim(raw);
          // version header
          if (StringTools.startsWith(line, '## '))
            {
              var ver = StringTools.trim(line.substr(3));
              out.add('<div class="mm-cl-vh"><span class="mm-cl-vnum">v' +
                StringTools.htmlEscape(ver) + '</span>' +
                (ver == current ? '<span class="mm-cl-cur">' + T('current') + '</span>' : '') + '</div>');
              section = null;
            }
          // section heading, held back until its first entry
          else if (StringTools.startsWith(line, '### '))
            section = StringTools.trim(line.substr(4));
          // entry: "tag: text" or plain text
          else if (StringTools.startsWith(line, '- '))
            {
              if (section != null)
                {
                  out.add('<div class="mm-cl-sec mm-cl-sec-' + section.toLowerCase() + '">' +
                    StringTools.htmlEscape(section) + '</div>');
                  section = null;
                }
              var text = line.substr(2);
              var colon = text.indexOf(': ');
              var tag = '<span></span>'; // empty first grid column
              if (colon > 0 &&
                  colon < 12)
                {
                  tag = '<span class="mm-cl-tag">' + StringTools.htmlEscape(text.substr(0, colon)) + '</span>';
                  text = text.substr(colon + 2);
                }
              out.add(tag + Const.small(StringTools.htmlEscape(text)));
            }
        }
      return '<div class="mm-cl-log">' + out.toString() + '</div>';
    }

// match the card: same top and height, just right of it
  function place()
    {
      var r = card.getBoundingClientRect();
      var screenW = Browser.window.innerWidth;
      var room = screenW - r.right;
      var width = Math.max(MIN_WIDTH, Math.min(MAX_WIDTH, room - CARD_GAP - GAP / 2));
      var left = Math.min(r.right + CARD_GAP, screenW - width - GAP / 2);
      panel.style.left = left + 'px';
      panel.style.top = r.top + 'px';
      panel.style.width = width + 'px';
      panel.style.height = r.height + 'px';
    }

// open/close the panel
  public function toggle()
    {
      if (isOpen())
        close();
      else open();
    }

// slide the panel in next to the card
  public function open()
    {
      place();
      panel.classList.add('open');
      button.classList.add('active');
      button.classList.remove('new');
      game.profile.markChangelog();
    }

// slide the panel out
  public function close()
    {
      panel.classList.remove('open');
      button.classList.remove('active');
    }

// is the panel open
  public inline function isOpen(): Bool
    {
      return panel.classList.contains('open');
    }
}
