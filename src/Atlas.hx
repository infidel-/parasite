// atlas for ai graphics

import h2d.Tile;

#if electron
import js.node.Fs;
#end

class Atlas
{
  var scene: GameScene;

  var maleAtlas: Array<Array<Tile>>; // male graphics
  var femaleAtlas: Array<Array<Tile>>; // female graphics
  var maleSpecialAtlas: Map<String, Array<Tile>>; // specials male
  var femaleSpecialAtlas: Map<String, Array<Tile>>; // specials female

  public function new(s: GameScene)
    {
      scene = s;

/*
      var file = Fs.readFileSync('resources/app/img/male64-1.png', 'utf8');
      var bts = haxe.io.Bytes.ofString(file);
      var res = hxd.res.Any.fromBytes('img/male64-1.png', bts).toTile();
*/
      var res = hxd.Res.load('graphics/male' + Const.TILE_SIZE_CLEAN +
        '.png').toTile();
      maleAtlas = res.grid(Const.TILE_SIZE_CLEAN);
      var res = hxd.Res.load('graphics/female' + Const.TILE_SIZE_CLEAN +
        '.png').toTile();
      femaleAtlas = res.grid(Const.TILE_SIZE_CLEAN);

      // nullify empty space (count on last row from the left!)
      var maleEmpty = 3;
      for (i in 0...maleEmpty)
        maleAtlas[9 - i][maleAtlas[0].length - 1] = null;
      var femaleEmpty = 5;
      for (i in 0...femaleEmpty)
        femaleAtlas[9 - i][femaleAtlas[0].length - 1] = null;

/*
      for (y in 0...maleAtlas[0].length)
        {
          var sbuf = new StringBuf();
          for (x in 0...10)
            sbuf.add(maleAtlas[x][y] == null ? '0' : '1');
          trace(sbuf.toString());
        }
      trace('==');
      for (y in 0...femaleAtlas[0].length)
        {
          var sbuf = new StringBuf();
          for (x in 0...10)
            sbuf.add(femaleAtlas[x][y] == null ? '0' : '1');
          trace(sbuf.toString());
        }
*/
      // scale atlases if needed
      if (scene.game.config.mapScale != 1)
        {
          for (i in 0...maleAtlas.length)
            for (j in 0...maleAtlas[i].length)
              if (maleAtlas[i][j] != null)
                maleAtlas[i][j].scaleToSize(Const.TILE_SIZE,
                  Const.TILE_SIZE);
          for (i in 0...femaleAtlas.length)
            for (j in 0...femaleAtlas[i].length)
              if (femaleAtlas[i][j] != null)
                femaleAtlas[i][j].scaleToSize(Const.TILE_SIZE,
                  Const.TILE_SIZE);
        }

      // form special atlases from complete ones
      // punch holes in complete ones
      maleSpecialAtlas = new Map();
      for (key => list in specialsMale)
        {
          var tmp = [];
          for (tpl in list)
            {
              tmp.push(maleAtlas[tpl.x][tpl.y]);
              maleAtlas[tpl.x][tpl.y] = null;
            }
          maleSpecialAtlas[key] = tmp;
        }

      femaleSpecialAtlas = new Map();
      for (key => list in specialsFemale)
        {
          var tmp = [];
          for (tpl in list)
            {
              tmp.push(femaleAtlas[tpl.x][tpl.y]);
              femaleAtlas[tpl.x][tpl.y] = null;
            }
          femaleSpecialAtlas[key] = tmp;
        }

/*
      for (y in 0...maleAtlas[0].length)
        {
          var sbuf = new StringBuf();
          for (x in 0...10)
            sbuf.add(maleAtlas[x][y] == null ? '0' : '1');
          trace(sbuf.toString());
        }
*/
    }

// get AI graphics with given params
  public function get(type: String, isMale: Bool): {
      tile: Tile,
      x: Int,
      y: Int,
    }
    {
      // dogs have different atlas
      if (type == 'dog')
        return {
          tile: scene.entityAtlas[1][Const.ROW_PARASITE],
          x: -1,
          y: -1,
        }

      // generic civilian
      else if (type == 'civilian')
        {
          var atlas = (isMale ? maleAtlas : femaleAtlas);
          var tile = null;
          for (i in 0...100)
            {
              var x = Std.random(atlas.length);
              var y = Std.random(atlas[0].length);
              tile = atlas[x][y];
              if (tile != null)
                return {
                  tile: tile,
                  x: x,
                  y: y,
                }
            }
          if (tile == null)
            {
              trace('could not find tile for ' + type + ' ' + isMale);
              return null;
            }
        }

      // special humans - police, soldier, agent, blackops, security
      else
        {
          var atlas = (isMale ? maleSpecialAtlas : femaleSpecialAtlas);
          if (!isMale && femaleSpecialAtlas[type] == null)
            atlas = maleSpecialAtlas;
          if (atlas[type] == null)
            {
              trace('no atlas for type ' + type);
              return null;
            }
          var len = atlas[type].length;
          var x = Std.random(len);
          var tile = atlas[type][x];
          return {
            tile: tile,
            x: x,
            y: -1,
          }
        }
      return null;
    }

// get specific AI graphics
  public function getXY(type: String, isMale: Bool, x: Int, y: Int): Tile
    {
      if (type == 'dog')
        return scene.entityAtlas[1][Const.ROW_PARASITE];
      else if (type == 'civilian')
        {
          var atlas = (isMale ? maleAtlas : femaleAtlas);
          var tile = atlas[x][y];
          if (tile == null)
            {
              trace('could not find tile at ' + x + ',' + y +
                ' for ' + type + ' ' + isMale);
              return null;
            }
          return tile;
        }
      else
        {
          var atlas = (isMale ? maleSpecialAtlas : femaleSpecialAtlas);
          if (!isMale && femaleSpecialAtlas[type] == null)
            atlas = maleSpecialAtlas;
          if (atlas[type] == null)
            {
              trace('no atlas for type ' + type);
              return null;
            }
          var tile = atlas[type][x];
          if (tile == null)
            {
              trace('could not find special tile at ' + x +
                ' for ' + type + ' ' + isMale);
              return null;
            }
          return tile;
        }
      return null;
    }

  static var specialsFemale = [
    'agent' => [
      { x: 8, y: 0 },
    ],
    'blackops' => [
      { x: 2, y: 6 },
      { x: 3, y: 6 },
      { x: 4, y: 6 },
      { x: 5, y: 6 },
      { x: 6, y: 6 },
      { x: 7, y: 6 },
      { x: 8, y: 6 },
      { x: 9, y: 6 },
    ],
    'police' => [
      { x: 0, y: 6 },
      { x: 1, y: 6 },
    ],
    'scientist' => [
      { x: 0, y: 7 },
      { x: 1, y: 7 },
      { x: 2, y: 7 },
      { x: 3, y: 7 },
      { x: 4, y: 7 },
    ],
    // NOTE: check start of file for empty tiles code on new row!
  ];

  static var specialsMale = [
    'police' => [
      { x: 9, y: 2 },
      { x: 1, y: 4 },
      { x: 4, y: 7 },
    ],
    'soldier' => [
      { x: 8, y: 7 },
    ],
    'agent' => [
      { x: 8, y: 1 },
    ],
    'blackops' => [
      { x: 3, y: 8 },
      { x: 4, y: 8 },
      { x: 5, y: 8 },
      { x: 6, y: 8 },
      { x: 7, y: 8 },
      { x: 8, y: 8 },
      { x: 9, y: 8 },
      { x: 0, y: 9 },
      { x: 1, y: 9 },
    ],
    'blackops-heavy' => [
      { x: 0, y: 8 },
      { x: 2, y: 8 },
    ],
    'security' => [
      { x: 1, y: 8 },
    ],
    'scientist' => [
      { x: 2, y: 9 },
      { x: 3, y: 9 },
      { x: 4, y: 9 },
      { x: 5, y: 9 },
      { x: 6, y: 9 },
    ],

    // NOTE: check start of file for empty tiles code on new row!
  ];
}

