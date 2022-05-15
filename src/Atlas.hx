// atlas for ai graphics

import h2d.Tile;

class Atlas
{
  var scene: GameScene;

  var maleAtlas: Array<Array<Tile>>; // male graphics
  var femaleAtlas: Array<Array<Tile>>; // female graphics
  var specialAtlas: Map<String, Array<Tile>>; // specials
  var interfaceAtlas: Map<String, Tile>; // interface tiles

  public function new(s: GameScene)
    {
      scene = s;

      // currently we assume there's no empty space
      var res = hxd.Res.load('graphics/male' + Const.TILE_SIZE_CLEAN +
        '.png').toTile();
      maleAtlas = res.grid(Const.TILE_SIZE_CLEAN);
      var res = hxd.Res.load('graphics/female' + Const.TILE_SIZE_CLEAN +
        '.png').toTile();
      femaleAtlas = res.grid(Const.TILE_SIZE_CLEAN);

      // nullify empty space
      var maleEmpty = 8;
      for (i in 0...maleEmpty)
        maleAtlas[9 - i][maleAtlas[0].length - 1] = null;

/*
      for (y in 0...maleAtlas[0].length)
        {
          var sbuf = new StringBuf();
          for (x in 0...10)
            sbuf.add(maleAtlas[x][y] == null ? '0' : '1');
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
      specialAtlas = new Map();
      for (key in specials.keys())
        {
          var tmp = [];
          var list = specials[key];
          for (tpl in list)
            {
              tmp.push(maleAtlas[tpl.x][tpl.y]);
              maleAtlas[tpl.x][tpl.y] = null;
            }
          specialAtlas[key] = tmp;
        }

      // interface graphics
      var tile = hxd.Res.load('graphics/interface.png').toTile();
      interfaceAtlas = new Map();
      for (def in interfaceDefs)
        interfaceAtlas[def.key] = tile.sub(def.x, def.y, def.w, def.h);
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
      // always take from male atlas
      else
        {
          if (specialAtlas[type] == null)
            {
              trace('no atlas for type ' + type);
              return null;
            }
          var len = specialAtlas[type].length;
          var x = Std.random(len);
          var tile = specialAtlas[type][x];
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
          if (specialAtlas[type] == null)
            {
              trace('no atlas for type ' + type);
              return null;
            }
          var tile = specialAtlas[type][x];
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


// get interface tile
  public inline function getInterface(key: String): Tile
    {
      return interfaceAtlas[key];
    }


  static var specials = [
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
      { x: 0, y: 8 },
    ],
    'security' => [
      { x: 1, y: 8 },
    ],
  ];

  static var interfaceDefs = [
/* x2
    { key: 'textUL', x: 51, y: 51, w: 13, h: 14 },
    { key: 'textDL', x: 51, y: 122, w: 13, h: 14 },
    { key: 'textU', x: 66, y: 51, w: 10, h: 14 },
    { key: 'textD', x: 67, y: 122, w: 10, h: 14 },
    { key: 'textL', x: 51, y: 66, w: 13, h: 10 },
    { key: 'textR', x: 602, y: 66, w: 14, h: 10 },
    { key: 'textUR', x: 602, y: 51, w: 14, h: 13 },
    { key: 'textDR', x: 602, y: 122, w: 14, h: 14 },
*/
    { key: 'textUL', x: 25, y: 25, w: 7, h: 7 },
    { key: 'textDL', x: 25, y: 61, w: 7, h: 7 },
    { key: 'textU', x: 32, y: 25, w: 5, h: 7 },
    { key: 'textD', x: 67, y: 61, w: 5, h: 7 },
    { key: 'textL', x: 25, y: 32, w: 5, h: 7 },
    { key: 'textR', x: 301, y: 32, w: 7, h: 5 },
    { key: 'textUR', x: 301, y: 25, w: 7, h: 7 },
    { key: 'textDR', x: 301, y: 61, w: 7, h: 7 },

    { key: 'button', x: 789, y: 306, w: 97, h: 43 },
    { key: 'buttonOver', x: 789, y: 358, w: 97, h: 43 },
    { key: 'buttonPress', x: 789, y: 412, w: 97, h: 43 },

    { key: 'sliderBack', x: 25, y: 300, w: 313, h: 23 },
    { key: 'sliderKnob', x: 2, y: 300, w: 22, h: 23 },

    { key: 'radio', x: 423, y: 298, w: 25, h: 24 },
    { key: 'radioPress', x: 451, y: 298, w: 25, h: 24 },
  ];
}

