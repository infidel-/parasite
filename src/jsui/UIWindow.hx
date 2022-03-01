// gui window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class UIWindow
{
  var game: Game;
  var window: DivElement;
  var state: _UIState; // state this relates to

  public function new(g: Game, id: String)
    {
      game = g;
      window = Browser.document.createDivElement();
      window.id = id;
      window.style.visibility = 'hidden';
      window.className = 'window text';
      Browser.document.body.appendChild(window);
    }

/*
// remove from scene
  public function remove()
    {
      window.remove();
    }


// center window on screen
  function center()
    {
      window.x = Std.int((game.scene.win.width - width) / 2);
      window.y = Std.int((game.scene.win.height - height) / 2);
      isCentered = true;
    }


// adds text widget into window with borders
  function addText(isHTML: Bool, x: Int, y: Int, w: Int, h: Int): Text
    {
      // color background
      back.beginFill(0x283134, 1);
      back.drawRect(x, y, w, h);
      back.endFill();

      // text (goes below the borders)
      var text = (isHTML ? new HtmlText(game.scene.font, back) :
        new Text(game.scene.font, back));

      // back on top of text hiding parts of it
      var back2 = new Graphics(back);
      back2.x = 0;
      back2.y = 0;
      back2.clear();
      back2.beginFill(0x56656a, 1);
      back2.drawRect(0, 0, x, height);
      back2.drawRect(0, 0, width, y);
      back2.drawRect(w + y, 0, width - w - y, height);
      back2.drawRect(0, h + y, width, height - h - y);
      back2.endFill();

      // text borders
      var bg = new Graphics(back);
      bg.x = x;
      bg.y = y;
//      bg.clear();
//      bg.beginTileFill(0, 0, 1, 1, tile);
//      bg.drawRect(0, 0, w, h);

#if !free
      // up
      var xx = 0;
      var tile = atlas.getInterface('textU');
      while (xx < w - tile.width)
        {
          bg.drawTile(xx, 0, tile);
          xx += Std.int(tile.width);
        }

      // down
      xx = 0;
      tile = atlas.getInterface('textD');
      while (xx < w - tile.width)
        {
          bg.drawTile(xx, h - tile.height, tile);
          xx += Std.int(tile.width);
        }

      // left
      var yy = 0;
      tile = atlas.getInterface('textL');
      while (yy < h - tile.height)
        {
          bg.drawTile(0, yy, tile);
          yy += Std.int(tile.height);
        }

      // right
      yy = 0;
      tile = atlas.getInterface('textR');
      while (yy < h - tile.height)
        {
          bg.drawTile(w - tile.width, yy, tile);
          yy += Std.int(tile.height);
        }

      // corners
      tile = atlas.getInterface('textUL');
      var textx = tile.width;
      var texty = tile.height + 5;
      bg.drawTile(0, 0, tile);
      tile = atlas.getInterface('textUR');
      var textx2 = tile.width;
      bg.drawTile(w - tile.width, 0, tile);
      tile = atlas.getInterface('textDL');
      bg.drawTile(0, h - tile.height, tile);
      tile = atlas.getInterface('textDR');
      bg.drawTile(w - tile.width, h - tile.height, tile);
#else
      var textx = 10;
      var textx2 = 10;
      var texty = 10;
#end

      text.x = x + textx;
      text.y = y + texty;
      text.maxWidth = w - text.x - textx2;

      return text;
    }

// add button to these coordinates
  function addButton(x: Int, y: Int, text: String,
      onClick: Void -> Void, ?onOver: Void -> Void, ?onOut: Void -> Void)
    {
      var tile1 = atlas.getInterface('button');
      var tile2 = atlas.getInterface('buttonOver');
      var tile3 = atlas.getInterface('buttonPress');
      var b = new Interactive(tile1.width, tile1.height, window);
      var img = new Anim([ tile1, tile2, tile3 ], 15, b);
      img.pause = true;
      b.x = (x > 0 ? x : Std.int((width - tile1.width) / 2));
      b.y = y;
      if (game.config.mouseEnabled)
        b.cursor = game.scene.mouse.atlas[Mouse.CURSOR_ARROW];
      b.onPush = function (e: Event)
        { img.currentFrame = 2; }
      b.onOver = function (e: Event)
        {
          img.currentFrame = 1;
          if (onOver != null)
            onOver();
        }
      b.onOut = function (e: Event)
        {
          img.currentFrame = 0;

          // KLUDGE: fix cursor on leaving button
          game.scene.mouse.forceNextUpdate = 5;
          if (onOut != null)
            onOut();
        }
      b.onClick = function (e: Event)
        {
          img.currentFrame = 1;
          onClick();
        }
      var t = new Text(font24, img);
      t.text = text;
      t.y = (tile1.height - t.textHeight) / 2;
      t.maxWidth = tile1.width;
      t.textAlign = Center;
    }


// make border
// does not work if addText() was called
  function makeBorder()
    {
      back.beginFill(0x273033, 0.75);
      back.lineStyle(4, 0x273033, 0.75);
      back.moveTo(2,0);
      back.lineTo(2,height);
      back.endFill();

      back.beginFill(0x273033, 0.75);
      back.lineStyle(4, 0x273033, 0.75);
      back.moveTo(4,height - 2);
      back.lineTo(width,height - 2);
      back.endFill();

      back.beginFill(0x273033, 0.75);
      back.lineStyle(4, 0x273033, 0.75);
      back.moveTo(width - 2,height - 4);
      back.lineTo(width - 2,0);
      back.endFill();

      back.beginFill(0x273033, 0.75);
      back.lineStyle(4, 0x273033, 0.75);
      back.moveTo(width - 4,2);
      back.lineTo(4,2);
      back.endFill();
    }
*/

// set window parameters
  public dynamic function setParams(obj: Dynamic)
    {}


// update window contents
  dynamic function update()
    {}


// action handling
  public dynamic function action(index: Int)
    {}


// scroll window up/down
  public dynamic function scroll(n: Int)
    {}


// scroll window to beginning
  public dynamic function scrollToBegin()
    {}


// scroll window to end
  public dynamic function scrollToEnd()
    {}


// show window
  public inline function show()
    {
      update();
      window.style.visibility = 'visible';
    }


// hide window
  public inline function hide()
    {
      window.style.visibility = 'hidden';
    }
}
