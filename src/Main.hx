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
        game.ui.state = UISTATE_MAINMENU;
        // pre-warm the 3D street shaders off the menu idle so the first city entry doesn't stall ~2s
        // under black compiling them on demand (see StreetView.warmup). the street canvas is hidden
        // (#streetview display:none) so this is invisible; delayed a beat so the menu paints first
        Browser.window.setTimeout(function() game.scene.city3d.warmup(), 300);
        return null;
      });
    }

  public static function main()
    {
      var m = new Main();
    }
}
