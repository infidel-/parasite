// blur on top of everything when UI loses focus

package ui;

import h2d.Text;

import game.Game;

class LoseFocus extends UIWindow
{
  public function new(g: Game)
    {
      super(g);

      var text = addText(false, 0, 0, width, height);
      text.text = 'CLICK TO CONTINUE';
      text.y = Std.int((game.scene.win.height - 20) / 2);
      text.textAlign = Center;

      game.scene.add(window, 100);
    }
}
