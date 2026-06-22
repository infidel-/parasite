// hud debug console block: command line with inline completion hint + history
package ui.hud;

import js.Browser;
import js.Browser.document;
import js.html.DivElement;
import js.html.TextAreaElement;
import js.html.KeyboardEvent;

import game.*;

class ConsoleHud
{
  var game: Game;
  var consoleDiv: DivElement;
  var console: TextAreaElement;
  var consoleHint: DivElement;
  var consoleHistoryIndex: Int;
  var consoleHistoryDraft: String;

  public function new(g: Game, h: HUD)
    {
      game = g;
      consoleDiv = document.createDivElement();
      consoleDiv.className = 'console-div';
      consoleDiv.style.visibility = 'hidden';
      h.container.appendChild(consoleDiv);

      console = document.createTextAreaElement();
      console.id = 'hud-console';
      consoleHistoryIndex = -1;
      consoleHistoryDraft = '';
      console.onkeydown = onConsoleKeyDown;
      console.oninput = function(_) updateConsoleHint();
      consoleDiv.appendChild(console);

      // gray inline hint overlay (sits over the textarea, typed part transparent)
      consoleHint = document.createDivElement();
      consoleHint.id = 'hud-console-hint';
      consoleHint.style.display = 'none';
      consoleDiv.appendChild(consoleHint);
    }

  public function visible(): Bool
    {
      return (consoleDiv.style.visibility == 'visible');
    }

  public function show()
    {
      consoleDiv.style.visibility = 'visible';
      console.value = '';
      Browser.window.setTimeout(function () {
        console.value = '';
      });
      console.focus();
      consoleHistoryIndex = -1;
      consoleHistoryDraft = '';
      updateConsoleHint();
    }

  public function hide()
    {
      consoleDiv.style.visibility = 'hidden';
      consoleHistoryIndex = -1;
      consoleHistoryDraft = '';
      consoleHint.style.display = 'none';
      game.ui.focus();
    }

// handle keyboard input for console
  function onConsoleKeyDown(e: KeyboardEvent)
    {
      // hide console
      if (e.code == 'Escape')
        {
          hide();
        }
      // run console command
      else if (e.code == 'Enter')
        {
          game.console.run(console.value);
          consoleHistoryIndex = -1;
          consoleHistoryDraft = '';
          // kludge: needs a timeout or closes the event window
          Browser.window.setTimeout(hide, 10);
        }
      // ctrl-w: delete the word before the caret (electron's close-window
      // accelerator on this chord is disabled in the host so it can't fire)
      else if (e.ctrlKey
          && e.code == 'KeyW')
        {
          e.preventDefault();
          var val = console.value;
          var caret = console.selectionStart;
          var i = caret;
          // skip whitespace immediately left of the caret, then the word itself
          while (i > 0 && val.charAt(i - 1) == ' ')
            i--;
          while (i > 0 && val.charAt(i - 1) != ' ')
            i--;
          console.value = val.substring(0, i) + val.substring(caret);
          console.selectionStart = i;
          console.selectionEnd = i;
          updateConsoleHint();
        }
      // tab completion (longest common prefix; lists ambiguous candidates)
      else if (e.code == 'Tab')
        {
          e.preventDefault();
          var r = game.console.completion.complete(console.value);
          if (r.value != console.value)
            {
              console.value = r.value;
              setConsoleCaretToEnd();
            }
          if (r.list.length > 0)
            game.console.log(r.list.join(', '));
          updateConsoleHint();
        }
      // previous command in history
      else if (e.code == 'ArrowUp')
        {
          if (game.console.getHistoryLength() == 0)
            return;
          e.preventDefault();
          if (consoleHistoryIndex == -1)
            {
              consoleHistoryDraft = console.value;
              consoleHistoryIndex = game.console.getHistoryLength();
            }
          if (consoleHistoryIndex > 0)
            consoleHistoryIndex--;
          console.value = game.console.getHistoryEntry(consoleHistoryIndex);
          setConsoleCaretToEnd();
          updateConsoleHint();
        }
      // next command in history
      else if (e.code == 'ArrowDown')
        {
          if (consoleHistoryIndex == -1)
            return;
          e.preventDefault();
          consoleHistoryIndex++;
          if (consoleHistoryIndex >= game.console.getHistoryLength())
            {
              consoleHistoryIndex = -1;
              console.value = consoleHistoryDraft;
            }
          else
            {
              console.value = game.console.getHistoryEntry(consoleHistoryIndex);
            }
          setConsoleCaretToEnd();
          updateConsoleHint();
        }
    }

// refresh the gray inline hint overlay from the current console input
  function updateConsoleHint()
    {
      var val = console.value;
      var h = game.console.completion.hint(val);
      if (h == '')
        {
          consoleHint.style.display = 'none';
          return;
        }
      consoleHint.style.display = '';
      // align the overlay box exactly over the textarea
      consoleHint.style.left = console.offsetLeft + 'px';
      consoleHint.style.top = console.offsetTop + 'px';
      consoleHint.style.width = console.offsetWidth + 'px';
      // mirror the textarea's exact computed font so the ghost lines up
      var cs = Browser.window.getComputedStyle(console);
      consoleHint.style.fontFamily = cs.fontFamily;
      consoleHint.style.fontSize = cs.fontSize;
      consoleHint.style.fontWeight = cs.fontWeight;
      consoleHint.style.lineHeight = cs.lineHeight;
      consoleHint.style.letterSpacing = cs.letterSpacing;
      consoleHint.style.height = cs.height;
      // transparent copy of typed text pushes the gray hint to the caret position
      consoleHint.innerHTML =
        '<span class="chint-pre">' + escapeHTML(val) + '</span>' +
        '<span class="chint-ghost">' + escapeHTML(h) + '</span>';
    }

// escapes html special chars for hint rendering
  function escapeHTML(s: String): String
    {
      s = StringTools.replace(s, '&', '&amp;');
      s = StringTools.replace(s, '<', '&lt;');
      s = StringTools.replace(s, '>', '&gt;');
      return s;
    }

// move console caret to the end
  function setConsoleCaretToEnd()
    {
      Browser.window.setTimeout(function () {
        untyped console.setSelectionRange(
          console.value.length,
          console.value.length);
      });
    }
}
