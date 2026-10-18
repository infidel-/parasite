// hud minimap block (the Absorb computer's map reward): the area's tile layout at 1px per cell under
// the event log, player dot on top. kind-agnostic — every area answers walkability off its tileset — and
// not fog-aware, like the 2D one it replaces. it shows through the hidden HUD while the options
// window is up, so the scale slider previews on it
package ui.hud;

import js.Browser;
import js.html.CanvasElement;

import game.Game;

class MinimapHud
{
  var game: Game;
  var canvas: CanvasElement; // what the HUD shows, in device pixels
  var base: CanvasElement; // the layout, 1px per cell
  var cells: Array<Array<Int>>; // cell grid the base was built from (a new area or a load swaps it)
  var ox: Int; // area cell at the base's top-left corner (the base is cropped to the walkable bounds)
  var oy: Int;

  // cell class colors: solid, floor, road. no see-through class: facility wall tiles answer
  // canSeeThrough true, so one painted the whole corp compound as glass
  static var COLORS = [
    [ 14, 16, 21 ],
    [ 122, 132, 152 ],
    [ 52, 58, 71 ],
  ];

  public function new(g: Game, h: HUD)
    {
      game = g;
      canvas = Browser.document.createCanvasElement();
      canvas.id = 'hud-minimap';
      canvas.className = 'hud-panel';
      h.container.appendChild(canvas);
      base = Browser.document.createCanvasElement();
    }

// show or hide the minimap and redraw it at the current scale with the player dot
  public function update()
    {
      var isShown = (game.location == LOCATION_AREA &&
        game.player.vars.mapAbsorbed);
      canvas.style.display = (isShown ? '' : 'none');
      if (!isShown)
        return;
      canvas.style.visibility = (game.ui.state == UISTATE_OPTIONS ? 'visible' : '');
      if (cells != game.area.getCells())
        build();

      // size in device pixels like the 2D one was, so the scale reads the same
      var scale = game.config.minimapScale;
      var w = Std.int(base.width * scale);
      var h = Std.int(base.height * scale);
      if (canvas.width != w ||
          canvas.height != h)
        {
          var dpr = Browser.window.devicePixelRatio;
          canvas.width = w;
          canvas.height = h;
          canvas.style.width = (w / dpr) + 'px';
          canvas.style.height = (h / dpr) + 'px';
        }
      // under the event log, which grows with its rows
      var log = Browser.document.getElementById('hud-log');
      canvas.style.top = (log.offsetTop + log.offsetHeight + 10) + 'px';

      var ctx = canvas.getContext2d();
      ctx.imageSmoothingEnabled = (scale < 1);
      ctx.drawImage(base, 0, 0, w, h);
      ctx.fillStyle = '#c441c4';
      ctx.beginPath();
      ctx.arc((game.playerArea.x - ox + 0.5) * scale, (game.playerArea.y - oy + 0.5) * scale,
        2 * scale, 0, Math.PI * 2, false);
      ctx.fill();
    }

// rebuild the 1px-per-cell layout from the area's tiles (objects left out, a door would go stale),
// cropped to the walkable bounds plus one cell: every area has a solid rim of its own width on each
// side, and drawn whole it framed the map in uneven dark margins
  function build()
    {
      var area = game.area;
      var tileset = area.getTileset();
      cells = area.getCells();
      // classify every cell and find the walkable bounds
      var classes = [];
      var x1 = area.width;
      var y1 = area.height;
      var x2 = -1;
      var y2 = -1;
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tileID = cells[x][y];
            var cls = (tileID == Const.TILE_ROAD ||
              tileID == Const.TILE_CROSSWALKV ||
              tileID == Const.TILE_CROSSWALKH ? 2 :
              tileset.isWalkable(tileID) ? 1 : 0);
            classes.push(cls);
            if (cls == 0)
              continue;
            x1 = Std.int(Math.min(x1, x));
            y1 = Std.int(Math.min(y1, y));
            x2 = Std.int(Math.max(x2, x));
            y2 = Std.int(Math.max(y2, y));
          }
      ox = Std.int(Math.max(x1 - 1, 0));
      oy = Std.int(Math.max(y1 - 1, 0));
      var w = Std.int(Math.min(x2 + 2, area.width)) - ox;
      var h = Std.int(Math.min(y2 + 2, area.height)) - oy;

      // paint the cropped rect
      base.width = w;
      base.height = h;
      var ctx = base.getContext2d();
      var img = ctx.createImageData(w, h);
      for (y in 0...h)
        for (x in 0...w)
          {
            var cls = classes[(y + oy) * area.width + x + ox];
            var i = (y * w + x) * 4;
            img.data[i] = COLORS[cls][0];
            img.data[i + 1] = COLORS[cls][1];
            img.data[i + 2] = COLORS[cls][2];
            img.data[i + 3] = 255;
          }
      ctx.putImageData(img, 0, 0);
    }
}
