// gui window

package ui;

import h2d.Anim;
import h2d.Bitmap;
import h2d.Font;
import h2d.Graphics;
import h2d.HtmlText;
import h2d.Interactive;
import h2d.Object;
import h2d.Text;
import h2d.TextInput;
import hxd.Event;

import game.Game;

class UIWindow
{
  var atlas: Atlas;
  var game: Game;
  var window: Object;
  var back: Graphics;
  var width: Int;
  var height: Int;
  var isScreenSize: Bool;
  var isCentered: Bool;
  var state: _UIState; // state this relates to
  var font24: Font;

  public function new(g: Game, ?w: Int, ?h: Int)
    {
      font24 = hxd.Res.font.OrkneyRegular24.toFont();
      game = g;
      atlas = game.scene.atlas;
      width = (w != null ? w : game.scene.win.width);
      height = (h != null ? h : game.scene.win.height);
      isCentered = false;
      isScreenSize = (w == null && h == null);
      window = new Object();
      window.x = 0;
      window.y = 0;
      window.visible = false;
      game.scene.add(window, Const.LAYER_UI);
      back = new Graphics(window);
      back.x = 0;
      back.y = 0;

//      back.bevel = 0;
      back.clear();
      back.beginFill(0x56656a, 1);
      back.drawRect(0, 0, width, height);
      back.endFill();
    }


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
/*
      if (isHTML)
        cast(text, HtmlText).loadFont = function (name: String)
          {
            trace(name);
            return null;
          }
*/

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


// add itch.io link
  function addItchLink(y: Int)
    {
      // image
      var tile = hxd.Res.load('graphics/logo_small.png').toTile();
#if js
      var b = new Interactive(tile.width, tile.height, window);
      var img = new Bitmap(tile, b);
      b.x = 10;
      b.y = y - 5;
      b.onOut = function (e: Event)
        {
          // KLUDGE: fix cursor on leaving button
          game.scene.mouse.forceNextUpdate = 5;
        }
      b.onClick = function (e: Event)
        {
          js.Browser.window.open('https://starinfidel.itch.io/parasite',
            '_blank');
        }
#else
      var img = new Bitmap(tile, window);
      img.x = 10;
      img.y = y - 5;
#end

      // text
      var back2 = new Graphics(back);
      var text = new Text(font24, back2);
      text.x = tile.width + 20;
      text.y = y + 10;
      text.textColor = 0x5febbd;
      text.text = 'https://starinfidel.itch.io/parasite';

      back2.beginFill(0x283134, 1);
      back2.drawRect(tile.width + 15, y + 5,
        text.textWidth + 10, text.textHeight + 10);
      back2.endFill();
#if js
      var b = new Interactive(text.textWidth + 10, text.textHeight + 10, window);
      b.x = text.x - 5;
      b.y = text.y - 5;
      b.onOut = function (e: Event)
        {
          // KLUDGE: fix cursor on leaving button
          game.scene.mouse.forceNextUpdate = 5;
        }
      b.onClick = function (e: Event)
        {
          js.Browser.window.open('https://starinfidel.itch.io/parasite',
            '_blank');
        }
#end
    }


// add button to these coordinates
  public function addButton(x: Int, y: Int, text: String,
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
      window.visible = true;
    }


// hide window
  public inline function hide()
    {
      window.visible = false;
    }
}
