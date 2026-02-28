// area save/load helper for compact area serialization format

package game;

class AreaGameSaver
{
// build compact serialized field overrides for area save data
  public static function save(area: AreaGame, formatVersion: Int): Dynamic
    {
      if (formatVersion < 2)
        return null;

      var w = area.width;
      var h = area.height;
      if (w <= 0 ||
          h <= 0)
        return null;
      if (!area.isGenerated)
        return {
          _cells: [],
          tiles: [],
        };

      var cellsData: Array<Dynamic> = cast area.getCells();
      var tilesData: Array<Dynamic> = cast area.getTiles();
      if (tilesData == null)
        tilesData = [];
      return {
        _cells: encodeCellsRLE(cellsData, w, h),
        tiles: encodeTileDecorations(tilesData, w, h),
      };
    }

// decode compact save data into legacy area fields before generic mapping
  public static function load(area: AreaGame,
      serialized: Dynamic, formatVersion: Int)
    {
      if (formatVersion < 2 ||
          serialized == null)
        return;
      var src: _AreaSaveData = cast serialized;

      var w = getHookInt(src.width, -1);
      var h = getHookInt(src.height, -1);
      if (w <= 0 ||
          h <= 0)
        return;
      if (src.isGenerated != true)
        {
          src._cells = [];
          src.tiles = [];
          return;
        }

      var cells: Dynamic = src._cells;
      if (Std.isOfType(cells, String))
        src._cells = decodeCellsRLE(cells, w, h);

      var decodedCells: Dynamic = src._cells;
      var tilesData: Dynamic = src.tiles;
      if (!Std.isOfType(tilesData, Array))
        tilesData = [];
      src.tiles = decodeTileDecorations(untyped tilesData,
        untyped decodedCells, w, h);
    }

// convert numeric dynamic value to int
  static function getHookInt(value: Dynamic, fallback: Int): Int
    {
      if (Std.isOfType(value, Int) ||
          Std.isOfType(value, Float))
        return Std.int(value);
      return fallback;
    }

// convert numeric dynamic value to float
  static function getHookFloat(value: Dynamic, fallback: Float): Float
    {
      if (Std.isOfType(value, Int) ||
          Std.isOfType(value, Float))
        return value;
      return fallback;
    }

// read one cell value from a 2d grid
  static function readGridCell(grid: Array<Dynamic>, x: Int, y: Int,
      fieldName: String): Int
    {
      if (x < 0 ||
          x >= grid.length)
        throw fieldName + ' is malformed: column out of bounds x=' + x;
      var col: Dynamic = grid[x];
      if (!Std.isOfType(col, Array))
        throw fieldName + ' is malformed: column is not an array x=' + x;
      var colArr: Array<Dynamic> = untyped col;
      if (y < 0 ||
          y >= colArr.length)
        throw fieldName + ' is malformed: row out of bounds x=' + x +
          ' y=' + y;
      var value: Dynamic = colArr[y];
      if (!Std.isOfType(value, Int) &&
          !Std.isOfType(value, Float))
        throw fieldName + ' is malformed: cell is not numeric x=' + x +
          ' y=' + y;
      return Std.int(value);
    }

// encode cells grid into row-major RLE string
  static function encodeCellsRLE(cells: Array<Dynamic>, w: Int, h: Int): String
    {
      var ret: Array<String> = [];
      var runValue = 0;
      var runCount = 0;
      var hasRun = false;
      for (y in 0...h)
        for (x in 0...w)
          {
            var value = readGridCell(cells, x, y, '_cells');
            if (!hasRun)
              {
                runValue = value;
                runCount = 1;
                hasRun = true;
                continue;
              }
            if (value == runValue)
              {
                runCount++;
                continue;
              }
            ret.push(runValue + '*' + runCount);
            runValue = value;
            runCount = 1;
          }
      if (hasRun)
        ret.push(runValue + '*' + runCount);
      return ret.join(';');
    }

// decode row-major RLE string into cells grid
  static function decodeCellsRLE(data: String, w: Int, h: Int): Array<Array<Int>>
    {
      if (data == null ||
          data.length == 0)
        throw '_cells RLE string is empty';

      var total = w * h;
      var index = 0;
      var cells: Array<Array<Int>> = [];
      for (x in 0...w)
        cells[x] = [];

      var tokens = data.split(';');
      for (token in tokens)
        {
          if (token == null ||
              token.length == 0)
            continue;
          var parts = token.split('*');
          if (parts.length != 2)
            throw '_cells RLE token malformed: ' + token;
          var value = Std.parseInt(parts[0]);
          var count = Std.parseInt(parts[1]);
          if (value == null ||
              count == null ||
              count <= 0)
            throw '_cells RLE token invalid: ' + token;

          for (_ in 0...count)
            {
              if (index >= total)
                throw '_cells RLE exceeds map size';
              var x = index % w;
              var y = Std.int(index / w);
              cells[x][y] = value;
              index++;
            }
        }

      if (index != total)
        throw '_cells RLE count mismatch: expected ' + total +
          ' got ' + index;
      return cells;
    }

// encode tile decorations into compact tuple grid
  static function encodeTileDecorations(tilesData: Array<Dynamic>,
      w: Int, h: Int): Array<Array<Array<Array<Dynamic>>>>
    {
      var ret: Array<Array<Array<Array<Dynamic>>>> = [];
      for (x in 0...w)
        {
          var srcCol: Array<Dynamic> = [];
          if (x < tilesData.length &&
              tilesData[x] != null &&
              Std.isOfType(tilesData[x], Array))
            srcCol = untyped tilesData[x];

          // each cell can have multiple decorations, so encode as array of tuples
          var outCol: Array<Array<Array<Dynamic>>> = [];
          for (y in 0...h)
            {
              var outCell: Array<Array<Dynamic>> = [];
              if (y < srcCol.length &&
                  srcCol[y] != null)
                {
                  var tile: _TileSaveData = cast srcCol[y];
                  var decorationData: Dynamic = tile.decoration;
                  if (Std.isOfType(decorationData, Array))
                    {
                      var decorations: Array<Dynamic> =
                        untyped decorationData;
                      for (decoration in decorations)
                        outCell.push(encodeDecorationTuple(decoration));
                    }
                }
              outCol[y] = outCell;
            }
          ret[x] = outCol;
        }
      return ret;
    }

// encode one decoration object as tuple
  static function encodeDecorationTuple(decoration: Dynamic): Array<Dynamic>
    {
      var dec: _DecorationSaveData = cast decoration;
      var layerID = getHookInt(dec.layerID, -1);
      var iconRow = -1;
      var iconCol = -1;
      var icon: _IconSaveData = cast dec.icon;
      if (icon != null)
        {
          iconRow = getHookInt(icon.row, -1);
          iconCol = getHookInt(icon.col, -1);
        }
      var dx = getHookInt(dec.dx, 0);
      var dy = getHookInt(dec.dy, 0);
      var scale = getHookFloat(dec.scale, 1.0);
      var angle = getHookFloat(dec.angle, 0.0);
      var tag: Dynamic = dec.tag;
      if (!Std.isOfType(tag, String))
        tag = null;
      return [layerID, iconRow, iconCol, dx, dy, scale, angle, tag];
    }

// decode compact tuple grid into runtime tile objects
  static function decodeTileDecorations(tilesData: Array<Dynamic>,
      cells: Array<Dynamic>, w: Int, h: Int): Array<Array<tiles.Tile>>
    {
      var ret: Array<Array<tiles.Tile>> = [];
      for (x in 0...w)
        {
          var srcCol: Array<Dynamic> = [];
          if (x < tilesData.length &&
              tilesData[x] != null &&
              Std.isOfType(tilesData[x], Array))
            srcCol = untyped tilesData[x];

          var outCol: Array<tiles.Tile> = [];
          for (y in 0...h)
            {
              var decorationList: Array<tiles.Decoration> = [];
              if (y < srcCol.length &&
                  srcCol[y] != null)
                {
                  var tuples: Array<Dynamic> = untyped srcCol[y];
                  for (tuple in tuples)
                    decorationList.push(decodeDecorationTuple(tuple, x, y));
                }

              outCol[y] = {
                id: readGridCell(cells, x, y, '_cells'),
                canSeeThrough: true,
                decoration: decorationList,
              };
            }
          ret[x] = outCol;
        }
      return ret;
    }

// decode one decoration tuple into object form
  static function decodeDecorationTuple(tuple: Dynamic,
      x: Int, y: Int): tiles.Decoration
    {
      if (!Std.isOfType(tuple, Array))
        throw 'tiles tuple malformed at x=' + x + ' y=' + y;

      var values: Array<Dynamic> = untyped tuple;
      if (values.length != 8)
        throw 'tiles tuple length malformed at x=' + x + ' y=' + y;

      var layerID = getHookInt(values[0], -1);
      var iconRow = getHookInt(values[1], -1);
      var iconCol = getHookInt(values[2], -1);
      var dx = getHookInt(values[3], 0);
      var dy = getHookInt(values[4], 0);
      var scale = getHookFloat(values[5], 1.0);
      var angle = getHookFloat(values[6], 0.0);
      var tag: Dynamic = values[7];
      if (!Std.isOfType(tag, String))
        tag = null;

      var decoration: tiles.Decoration = {
        layerID: layerID,
        dx: dx,
        dy: dy,
        scale: scale,
        angle: angle,
      };
      if (iconRow >= 0 &&
          iconCol >= 0)
        decoration.icon = {
          row: iconRow,
          col: iconCol,
        };
      if (tag != null)
        decoration.tag = tag;
      return decoration;
    }
}

typedef _AreaSaveData = {
  var width: Dynamic;
  var height: Dynamic;
  var isGenerated: Dynamic;
  var _cells: Dynamic;
  var tiles: Dynamic;
}

typedef _TileSaveData = {
  var decoration: Dynamic;
}

typedef _DecorationSaveData = {
  var layerID: Dynamic;
  var icon: Dynamic;
  var dx: Dynamic;
  var dy: Dynamic;
  var scale: Dynamic;
  var angle: Dynamic;
  var tag: Dynamic;
}

typedef _IconSaveData = {
  var row: Dynamic;
  var col: Dynamic;
}
