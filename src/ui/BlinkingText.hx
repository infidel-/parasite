// blinking text in the middle of the screen

package ui;

import h2d.Graphics;
import h2d.Object;
import game.Game;

class BlinkingText
{
  var game: Game; // game state link
  var text: h2d.Text; // team member notification 
  var back: Graphics; // notification background
  var textAlphaTarget: Float; // notification alpha animation
  var times: Int; // times to blink until hiding

  public function new(g: Game, container: Object)
    {
      game = g;

      times = 0;
      back = new Graphics(container);
      text = new h2d.Text(game.scene.font40, back);
      text.textAlign = Left;
      text.text = 'You feel someone watching you.';
      text.textColor = 0xff3333;
      back.x = Std.int(game.scene.win.width / 2 -
        text.textWidth / 2);
      back.y = game.scene.win.height / 2;
      back.clear();
      back.beginFill(0x202020, 0.75);
      back.drawRect(0, 0, text.textWidth,
        text.textHeight);
      back.endFill();
      back.visible = false;
      textAlphaTarget = 1.0;
    }


// resize notification
  public function resize()
    {
      back.x = Std.int(game.scene.win.width / 2 -
        text.textWidth / 2);
      back.y = game.scene.win.height / 2;
    }


// show for a given amount of time
  public function show(t: Int)
    {
      back.visible = true;
      times = t;
    }


// periodic update for animation
  public function update(dt: Float)
    {
      if (!back.visible)
        return;

      if (textAlphaTarget == 1.0)
        {
          back.alpha += 0.02;
          if (back.alpha >= 1.0)
            textAlphaTarget = 0.0;
        }
      else
        {
          back.alpha -= 0.02;
          if (back.alpha <= 0.0)
            {
              textAlphaTarget = 1.0;
              times--;
              if (times <= 0) // hide
                back.visible = false;
            }
        }
    }
}
