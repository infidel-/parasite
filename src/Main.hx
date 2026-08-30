import game.Game;

import js.Browser;

class Main
{
  public var game: Game;
  public function new()
    {
      Browser.window.setTimeout(init, 1);
    }

// engine init entry-point
  function init()
    {
      // resolve runtime debug flag before any guarded code runs.
      // Config ctor (via new Game()) reads Const.isDebug
#if electron
      Const.isDebug = HostBridge.isDebug;
#end

      // new canvas (no heaps)
      var canvas = Browser.document.createCanvasElement();
      canvas.id = 'canvas';
      canvas.width = Math.ceil(Browser.window.innerWidth * Browser.window.devicePixelRatio);
      canvas.height = Math.ceil(Browser.window.innerHeight * Browser.window.devicePixelRatio);
      var ctx = canvas.getContext('2d');
      ctx.textAlign = 'center';
      Browser.document.body.appendChild(canvas);
      canvas.focus();

      game = new Game();
      // the boot screen (#warmup in app.html) is up from the document's first paint, but its FONT is
      // not settled until here: it renders in --text-font-title, and the Config ctor inside the line
      // above is what replaces that with the player's saved choice. so the words are transparent in
      // app.css and get switched on once that face has actually loaded — attached AFTER new Game()
      // on purpose, so the load fonts.ready waits on is the configured one and not the :root default
      var warm = Browser.document.getElementById('warmup');
      if (warm != null)
        untyped Browser.document.fonts.ready.then(function(_) warm.classList.add('ready'));
      // exit-save: flush a forced autosave on any graceful exit (in-game quit,
      // OS window close, reload). saveWrite is sync IPC so it completes here.
#if electron
      Browser.window.addEventListener('beforeunload', function(_) {
        game.autosave(true);
      });
#end
      ai.CommonLogic.game = game;
      ai.DefaultLogic.game = game;
      ai.FollowerLogic.game = game;
      ai.CommandLogic.game = game;
      game.scene.init();
      mods.ModLoader.load(game).then(function(_) {
        // pre-warm the 3D shaders so the first area entry doesn't stall ~2s under black compiling
        // them on demand (see render.View.warmup). it used to run off the menu idle, but its head is
        // a second or more of blocked main thread building three throwaway cities, a tunnel and a
        // facility, and its tail stalls again on every glb that lands — all of it under a menu that
        // had already painted and then froze mid-animation. so the menu is held back instead: the
        // #warmup screen in app.html is up from the document's first paint, and this is what takes
        // it down. reveal is one-shot — the warm's own callback normally fires it, the timer is the
        // backstop for a warm that never settles (a dead glb load once did exactly that)
        var revealed = false;
        var reveal = function()
          {
            if (revealed)
              return;
            revealed = true;
            var w = Browser.document.getElementById('warmup');
            if (w != null)
              w.remove();
            game.ui.state = UISTATE_MAINMENU;
          };
        Browser.window.setTimeout(reveal, 30000);
        game.scene.view3d.warmup(reveal);
        return null;
      });
    }

  public static function main()
    {
      var m = new Main();
    }
}
