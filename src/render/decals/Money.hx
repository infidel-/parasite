package render.decals;

import citygen.CityConfig;
import render.RenderConfig;
import render.particles.Sprites;
import render.world.WorldCtx;

// one lingering thrown-money ground stain (fading variant): a cell + randomized look. `age` (BASE_MS
// units, real time) is only used by the fading (temporary) stains; permanent stains ignore it
typedef MoneySpot = {
  col:Int,         // tile column
  row:Int,         // tile row
  scale:Float,     // stain scale (of a billboard)
  angle:Float,     // in-plane rotation
  dx:Float,        // sub-cell x offset (cells)
  dz:Float,        // sub-cell z offset (cells)
  age:Float,       // lifetime clock for temporary stains (BASE_MS units)
};

// MONEY thrown-money ground stains. permanent stains are persisted model tile-decorations (drawn
// through the coordinator's grid scan via draw(), matte + dark like trash); the fading stains live
// view-side in `temp`, resting at full opacity then smoothly fading out and dropping
class Money {
  var d:Decals;                                          // coordinator back-ref (batch, sprites, radiusOp, game)
  var temp:Array<MoneySpot> = [];                        // fading stains (view-side, real-time rest+fade)

  public function new(d:Decals)
    {
      this.d = d;
    }

// lay the lingering money ground stains over the throw radius: one flat decal per walkable cell
// within range. ~MONEY.permFrac stay permanent (persisted tile-decorations in the shared dynamic-
// decal FIFO, like blood splats); the rest are view-side stains that fade out
  public function throwGround(x:Int, y:Int, range:Int):Void
    {
      var M = RenderConfig.MONEY;
      var t = Const.TILE_SIZE;
      for (yy in y - range...y + range + 1)
        for (xx in x - range...x + range + 1)
          {
            if (!d.game.area.isWalkable(xx, yy))
              continue;
            if (Const.distanceSquared(x, y, xx, yy) > range * range)
              continue;
            if (Math.random() < M.permFrac)
              // permanent: a model tile-decoration. layerID -1 => 2D floor-decoration draw skips it
              // (money uses the 3D entities atlas, not a 2D splat layer); 3D draws it via draw()
              d.game.area.addTileDecoration(xx, yy, {
                layerID: -1,
                icon: { row: Const.ROW_EFFECT, col: Const.FRAME_EFFECT_MONEY },
                dx: Std.int((Math.random() - 0.5) * 2 * M.groundScatter * t),
                dy: Std.int((Math.random() - 0.5) * 2 * M.groundScatter * t),
                scale: M.groundScaleMin + Math.random() * (M.groundScaleMax - M.groundScaleMin),
                angle: Math.random() * Math.PI * 2,
                tag: 'MONEY',
              });
            else addTemp(xx, yy);
          }
    }

// register a fading (temporary) money ground stain on a walkable cell (col,row): rests at full
// opacity then fades out and drops. randomized scale/angle/offset like the 2D onDeath decal
  function addTemp(col:Int, row:Int):Void
    {
      var M = RenderConfig.MONEY;
      temp.push({
        col: col,
        row: row,
        scale: M.groundScaleMin + Math.random() * (M.groundScaleMax - M.groundScaleMin),
        angle: Math.random() * Math.PI * 2,
        dx: (Math.random() - 0.5) * 2 * M.groundScatter,
        dz: (Math.random() - 0.5) * 2 * M.groundScatter,
        age: 0.0,
      });
    }

// permanent thrown-money stain: flat matte ground quad from the money atlas, darkened like trash
// (no wet sheen), radius-faded around the player. the fading ones live in `temp` (see paintTemp)
  public function draw(dec:tiles.Decoration, x:Int, y:Int, t:Float):Bool
    {
      if (dec.icon == null)
        return false;
      var dx = (dec.dx != null ? dec.dx : 0) / t;
      var dy = (dec.dy != null ? dec.dy : 0) / t;
      var w = CityConfig.cellToWorld(x + dx, y + dy);
      var op = d.radiusOp(w.x, w.z);
      if (op <= 0.001)
        return false;
      var atlas = d.sprites.atlasTex('entities', false, RenderConfig.DECAL.debrisMul);
      var r = d.sprites.cellRect('entities', dec.icon.col, dec.icon.row, false);
      if (atlas == null ||
          r == null)
        return false;
      var sc = (dec.scale != null ? dec.scale : 1.0);
      // +0.05: sit proud of the road (more depth margin than blood's +0.04 to kill z-fighting)
      d.batch.add(atlas, r, w.x, WorldCtx.floorY(x, y) + 0.05, w.z,
        Sprites.SIZE * sc, Sprites.SIZE * sc, (dec.angle != null ? dec.angle : 0.0),
        op, 1.0, 0.0);
      return true;
    }

// draw the fading money stains: each advances its real-time rest+fade clock and drops once fully
// faded (removed back-to-front so splice keeps indices). flat matte quad from the money atlas,
// darkened like trash + radius-faded around the player
  public function paintTemp(dtMs:Float):Void
    {
      if (temp.length == 0)
        return;
      var M = RenderConfig.MONEY;
      var atlas = d.sprites.atlasTex('entities', false, RenderConfig.DECAL.debrisMul);
      var r = d.sprites.cellRect('entities', Const.FRAME_EFFECT_MONEY, Const.ROW_EFFECT, false);
      if (atlas == null ||
          r == null)
        return;
      var dt = dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      var i = temp.length - 1;
      while (i >= 0)
        {
          var m = temp[i];
          m.age += dt;
          // rest at full opacity, then a smooth linear fade-out, then drop
          var op = 1.0;
          if (m.age > M.tempHoldMult)
            op = 1 - (m.age - M.tempHoldMult) / M.tempFadeMult;
          if (op <= 0.0)
            {
              temp.splice(i, 1);
              i--;
              continue;
            }
          var w = CityConfig.cellToWorld(m.col + m.dx, m.row + m.dz);
          var rop = d.radiusOp(w.x, w.z) * op;
          if (rop > 0.001)
            d.batch.add(atlas, r, w.x, WorldCtx.floorY(m.col, m.row) + 0.05, w.z,
              Sprites.SIZE * m.scale, Sprites.SIZE * m.scale, m.angle, rop, 1.0, 0.0);
          i--;
        }
    }
}
