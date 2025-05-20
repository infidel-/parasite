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
      ai.DefaultLogic.game = game;
      game.scene.init();
      game.ui.state = UISTATE_MAINMENU;
    }

  public static function main()
    {
      var m = new Main();
    }
}
