// atlas for ai graphics

import h2d.Tile;

class Atlas
{
  var scene: GameScene;

  var maleAtlas: Array<Array<Tile>>; // male graphics
  var femaleAtlas: Array<Array<Tile>>; // female graphics
  var specialAtlas: Map<String, Array<Tile>>; // specials

  public function new(s: GameScene)
    {
      scene = s;

      // currently we assume there's no empty space
      var res = hxd.Res.load('graphics/male' + Const.TILE_WIDTH +
        '.png').toTile();
      maleAtlas = res.grid(Const.TILE_WIDTH);
      var res = hxd.Res.load('graphics/female' + Const.TILE_WIDTH +
        '.png').toTile();
      femaleAtlas = res.grid(Const.TILE_WIDTH);

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
    }


// get AI graphics with given params
  public function get(type: String, isMale: Bool): Tile
    {
      var tile = null;

      // dogs have different atlas
      if (type == 'dog')
        tile = scene.entityAtlas[1][Const.ROW_PARASITE];

      // generic civilian
      else if (type == 'civilian')
        {
          var atlas = (isMale ? maleAtlas : femaleAtlas);
          for (i in 0...100)
            {
              var x = Std.random(atlas.length);
              var y = Std.random(atlas[0].length);
              tile = atlas[x][y];
              if (tile != null)
                break;
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
          tile = specialAtlas[type][Std.random(len)];

          return tile;
        }

      return tile;
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
}

