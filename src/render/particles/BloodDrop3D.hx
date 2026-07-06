package render.particles;

import game.Game;
import citygen.CityConfig;
import render.world.WorldCtx;
import render.RenderConfig;

// one blood droplet: a ballistic arc thrown from a hit, drawn as a small flat quad, that on
// landing commits a persisted SPLAT ground decoration (which the decal pass then renders and
// saves/clears like any splat). the transient particle is the writer; the decal is the record
class BloodDrop3D extends Particle3D {
  var game:Game;
  var x:Float; var y:Float; var z:Float;                // world pos
  var vx:Float; var vy:Float; var vz:Float;             // world velocity (units/sec)
  var floor:Float;                                      // ground height it lands on
  var ix:Int; var iy:Int;                               // blood atlas cell for the landed splat

  public function new(game:Game, x:Float, y:Float, z:Float, vx:Float, vy:Float, vz:Float, floor:Float, ix:Int, iy:Int)
    {
      super();
      this.game = game;
      this.x = x; this.y = y; this.z = z;
      this.vx = vx; this.vy = vy; this.vz = vz;
      this.floor = floor;
      this.ix = ix; this.iy = iy;
    }

// throw a burst of drops from a target cell, biased away from the attacker; each arcs then lands
// as a SPLAT decal. bloodRow/bloodFirstCol pick the blood variant by type
  public static function burst(particles:Particles3D, game:Game, tgtCol:Int, tgtRow:Int, awayX:Float, awayZ:Float, bloodRow:Int, bloodFirstCol:Int):Void
    {
      var origin = CityConfig.cellToWorld(tgtCol, tgtRow);
      var floor = WorldCtx.floorY(tgtCol, tgtRow);
      // normalize the away-from-attacker direction (fallback: random)
      var len = Math.sqrt(awayX * awayX + awayZ * awayZ);
      if (len < 0.001)
        { awayX = 1; awayZ = 0; len = 1; }
      awayX /= len; awayZ /= len;
      for (_ in 0...RenderConfig.BLOOD.drops)
        {
          // spread each drop around the away direction with a random sideways kick + speed
          var side = (Math.random() - 0.5) * 1.4;
          var dirX = awayX + -awayZ * side;
          var dirZ = awayZ + awayX * side;
          var spd = RenderConfig.BLOOD.speed * CityConfig.CELL * (0.4 + Math.random());
          particles.add(new BloodDrop3D(game,
            origin.x, floor + Sprites.SIZE * 0.4, origin.z,
            dirX * spd, RenderConfig.BLOOD.up * (0.6 + 0.8 * Math.random()), dirZ * spd,
            floor,
            bloodFirstCol + Std.random(5), // SPLAT_NUM variants
            bloodRow));
        }
    }

// integrate one frame of ballistic flight; return false once it hits the ground
  override public function tick(dtMs:Float):Bool
    {
      var dt = dtMs / 1000.0;
      vy -= RenderConfig.BLOOD.gravity * dt;
      x += vx * dt;
      y += vy * dt;
      z += vz * dt;
      return y > floor;
    }

// draw the in-flight droplet as a small flat quad
  override public function draw(p:Paint3D):Void
    {
      var g = p.sprites;
      g.paint(x, y, z, g.tex('entities', ix, iy, false), 1.0, RenderConfig.BLOOD.dropScale, false);
    }

// on landing, write the drop as a persisted SPLAT tile decoration (cell + sub-cell offset)
  override public function onDeath():Void
    {
      var colF = x / CityConfig.CELL + CityConfig.GRID / 2 - 0.5;
      var rowF = z / CityConfig.CELL + CityConfig.GRID / 2 - 0.5;
      var col = Math.round(colF), row = Math.round(rowF);
      if (!game.area.isWalkable(col, row))
        return;
      var t = Const.TILE_SIZE;
      game.area.addTileDecoration(col, row, {
        layerID: game.area.getTileset().splatLayerID,
        icon: { row: iy, col: ix },
        dx: Std.int((colF - col) * t),
        dy: Std.int((rowF - row) * t),
        scale: Const.round2(RenderConfig.BLOOD.scaleMin +
          (RenderConfig.BLOOD.scaleMax - RenderConfig.BLOOD.scaleMin) * Math.random()),
        angle: Const.round2(2 * Math.PI * Math.random()),
        tag: 'SPLAT',
      });
    }
}
