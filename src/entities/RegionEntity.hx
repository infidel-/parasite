// region icon entity (does not need a container and does not extend base entity class)

package entities;

import h2d.Bitmap;

class RegionEntity
{
  var scene: GameScene;

  var _body: Bitmap; // body sprite
  public var atlasRow: Int; // tile atlas row
  public var atlasCol: Int; // tile atlas row
  public var x: Int;
  public var y: Int;


  public function new(s: GameScene, xx: Int, yy: Int, row: Int, col: Int)
    {
      atlasRow = row;
      atlasCol = col;
      scene = s;
      x = xx;
      y = yy;

      _body = new Bitmap(scene.entityAtlas[atlasCol][atlasRow],
        scene.region.icons);
      _body.x = x * Const.TILE_SIZE;
      _body.y = y * Const.TILE_SIZE;
    }


// set image index
  public function setImage(col: Int)
    {
      if (atlasCol == col)
        return;

      atlasCol = col;
      _body.remove();
      _body = new Bitmap(scene.entityAtlas[col][atlasRow],
        scene.region.icons);
      _body.x = x * Const.TILE_SIZE;
      _body.y = y * Const.TILE_SIZE;
    }


// remove from scene
  public function remove()
    {
      if (_body == null)
        return;
      _body.remove();
      _body = null;
    }
}
