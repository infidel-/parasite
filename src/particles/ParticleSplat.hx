package particles;

import js.html.CanvasRenderingContext2D;
import Const.TILE_SIZE as tile;

class ParticleSplat extends Particle
{
  public static var SPLAT_NUM = 5;
  public static var SPLAT_TAG = 'SPLAT';
  static var SPLAT_CONE_HALF_COS = 0.5;

  // area x,y
  var pt: _Point;
  var source: _Point;
  var row: Int;
  var firstCol: Int;

  public function new(s: GameScene, type: String, pt: _Point, ?source: _Point)
    {
      super(s);
      this.pt = pt;
      this.source = source;
      row = Const.ROW_BLOOD;
      firstCol = Const.BLOOD_LARGE;
      switch (type)
        {
          case 'black':
            row = Const.ROW_BLOOD;
            firstCol = Const.BLACK_BLOOD_LARGE;
          case 'acid':
            row = Const.ROW_SPACESHIP1;
            firstCol = Const.ACID_LARGE;
          case 'slime':
            row = Const.ROW_SPACESHIP2;
            firstCol = Const.SLIME_LARGE;
          default:
        }
      this.time = 80;
      game.scene.area.addParticle(this);
    }

// scale image
  public override function draw(ctx: CanvasRenderingContext2D, dt: Float)
    {
      var dsize = dt * tile;
      ctx.drawImage(game.scene.images.entities,
        firstCol * Const.TILE_SIZE_CLEAN,
        row * Const.TILE_SIZE_CLEAN + 1,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN - 1,

        (pt.x - game.scene.cameraTileX1) * tile + tile / 2 - dsize / 2,
        (pt.y - game.scene.cameraTileY1) * tile + tile / 2 - dsize / 2,
        dsize,
        dsize);
    }

// create ground splat on death
  public override function onDeath()
    {
      var tileset = game.scene.images.getTileset(game.area.typeID);
      var layerID = tileset.splatLayerID;
      if (layerID < 0 ||
          !game.area.isWalkable(pt.x, pt.y))
        return;

      // try to find random placement for one of the splat variants, if possible
      var col = Const.roll(firstCol, firstCol + SPLAT_NUM - 1);
      var scale = Const.round2(0.1 + 0.9 * Math.random());
      var angle = Const.round2(360 * Math.random() * Math.PI / 180);
      var dx = 0;
      var dy = 0;
      var hasPlacement = false;
      for (_ in 0...16)
        {
          // try random offset in +/-50% tile range
          var candidateDX = randomSplatOffset();
          var candidateDY = randomSplatOffset();
          if (!isInsideSplatCone(candidateDX, candidateDY) ||
              !canPlaceSplatWithOffset(candidateDX, candidateDY,
                scale, angle))
            continue;
          dx = candidateDX;
          dy = candidateDY;
          hasPlacement = true;
          break;
        }

      // if no good random placement found, try centered placement as fallback
      if (!hasPlacement &&
          !canPlaceSplatWithOffset(0, 0, scale, angle))
        return;

      // add splat decoration on top of all other layers, with random offset, scale and angle
      game.area.addTileDecoration(pt.x, pt.y, {
        layerID: layerID,
        icon: {
          row: row,
          col: col,
        },
        dx: dx,
        dy: dy,
        scale: scale,
        angle: angle,
        tag: SPLAT_TAG,
      });
    }

// get random tile-local offset in +/-50% tile range
  function randomSplatOffset(): Int
    {
      var half = Std.int(tile / 2);
      return -half + Std.random(half * 2 + 1);
    }

// check if offset direction is inside opposite-shot cone
  function isInsideSplatCone(dx: Int, dy: Int): Bool
    {
      if (source == null ||
          (source.x == pt.x && source.y == pt.y) ||
          (dx == 0 && dy == 0))
        return true;

      // direction from source to candidate splat position
      var dirX = pt.x - source.x;
      var dirY = pt.y - source.y;
      var dirLen = Math.sqrt(dirX * dirX + dirY * dirY);
      if (dirLen <= 0.0001)
        return true;
      var candidateLen = Math.sqrt(dx * dx + dy * dy);
      if (candidateLen <= 0.0001)
        return true;

      // dot product of candidate offset and source direction, normalized by their lengths, should be above cone threshold
      var dot = dx * dirX + dy * dirY;
      return dot >= candidateLen * dirLen * SPLAT_CONE_HALF_COS;
    }

// check whether rotated transformed splat stays on walkable neighbours
  function canPlaceSplatWithOffset(dx: Int, dy: Int,
      scale: Float, angle: Float): Bool
    {
      // splats are only allowed on floors
      if (!game.area.isWalkable(pt.x, pt.y))
        return false;

      var scaledSize = tile * scale;
      var halfSize = scaledSize / 2;
      var absCos = Math.abs(Math.cos(angle));
      var absSin = Math.abs(Math.sin(angle));
      var halfExtent = halfSize * (absCos + absSin);
      var centerX = tile / 2 + dx;
      var centerY = tile / 2 + dy;
      var localX1 = centerX - halfExtent;
      var localY1 = centerY - halfExtent;
      var localX2 = centerX + halfExtent;
      var localY2 = centerY + halfExtent;

      var touchesLeft = localX1 < 0;
      var touchesRight = localX2 > tile;
      var touchesTop = localY1 < 0;
      var touchesBottom = localY2 > tile;

      // if splat touches tile edge, check that adjacent tile is walkable
      if (touchesLeft &&
          !game.area.isWalkable(pt.x - 1, pt.y))
        return false;
      if (touchesRight &&
          !game.area.isWalkable(pt.x + 1, pt.y))
        return false;
      if (touchesTop &&
          !game.area.isWalkable(pt.x, pt.y - 1))
        return false;
      if (touchesBottom &&
          !game.area.isWalkable(pt.x, pt.y + 1))
        return false;

      // if splat touches tile corner, check that diagonal tile is walkable
      if (touchesLeft &&
          touchesTop &&
          !game.area.isWalkable(pt.x - 1, pt.y - 1))
        return false;
      if (touchesRight &&
          touchesTop &&
          !game.area.isWalkable(pt.x + 1, pt.y - 1))
        return false;
      if (touchesLeft &&
          touchesBottom &&
          !game.area.isWalkable(pt.x - 1, pt.y + 1))
        return false;
      if (touchesRight &&
          touchesBottom &&
          !game.area.isWalkable(pt.x + 1, pt.y + 1))
        return false;

      return true;
    }
}
