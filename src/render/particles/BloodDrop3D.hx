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
  var prevCol:Int; var prevRow:Int;                     // last open cell flown through (wall-face pick)
  var hitWall:Bool = false;                             // died entering a solid cell -> splat its face

  public function new(game:Game, x:Float, y:Float, z:Float, vx:Float, vy:Float, vz:Float, floor:Float, ix:Int, iy:Int)
    {
      super();
      this.game = game;
      this.x = x; this.y = y; this.z = z;
      this.vx = vx; this.vy = vy; this.vz = vz;
      this.floor = floor;
      this.ix = ix; this.iy = iy;
      prevCol = Math.round(x / CityConfig.CELL + CityConfig.GRID / 2 - 0.5);
      prevRow = Math.round(z / CityConfig.CELL + CityConfig.GRID / 2 - 0.5);
    }

// throw a burst of drops from a target cell, biased away from the attacker (a zero away vector
// scatters each drop in a random direction instead — bleeding drips with no attacker); each arcs
// then lands as a SPLAT decal. bloodRow/bloodFirstCol pick the blood variant by type; drops <= 0
// falls back to the full combat count
  public static function burst(particles:Particles3D, game:Game, tgtCol:Int, tgtRow:Int, awayX:Float, awayZ:Float, bloodRow:Int, bloodFirstCol:Int, drops:Int = 0):Void
    {
      var origin = CityConfig.cellToWorld(tgtCol, tgtRow);
      var floor = WorldCtx.floorY(tgtCol, tgtRow);
      if (drops <= 0)
        drops = RenderConfig.BLOOD.drops;
      // normalize the away-from-attacker direction (zero = unbiased, random per drop)
      var len = Math.sqrt(awayX * awayX + awayZ * awayZ);
      var biased = len >= 0.001;
      if (biased)
        {
          awayX /= len;
          awayZ /= len;
        }
      for (_ in 0...drops)
        {
          // spread each drop around the away direction with a random sideways kick + speed,
          // or fully around the circle when unbiased
          var dirX;
          var dirZ;
          if (biased)
            {
              var side = (Math.random() - 0.5) * 1.4;
              dirX = awayX + -awayZ * side;
              dirZ = awayZ + awayX * side;
            }
          else
            {
              var a = 2 * Math.PI * Math.random();
              dirX = Math.cos(a);
              dirZ = Math.sin(a);
            }
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
      // entered a solid cell: stick to that wall (checked before the floor so the drop dies on the
      // wall it flew into, not the ground past it). else remember this open cell as the last one
      // before a possible wall and keep arcing until it drops to the floor
      var col = Math.round(x / CityConfig.CELL + CityConfig.GRID / 2 - 0.5);
      var row = Math.round(z / CityConfig.CELL + CityConfig.GRID / 2 - 0.5);
      if (!game.area.canSeeThrough(col, row))
        {
          hitWall = true;
          return false;
        }
      prevCol = col; prevRow = row;
      return y > floor;
    }

// draw the in-flight droplet as a small flat quad; black blood glows faint violet in flight
// (otherworldly, matching its landed shimmer — too short-lived to hue-cycle)
  override public function draw(p:Paint3D):Void
    {
      var g = p.sprites;
      var black = iy == Const.ROW_BLOOD &&
        ix >= Const.BLACK_BLOOD_LARGE;
      g.paint(x, y, z, g.tex('entities', ix, iy, false), 1.0, RenderConfig.BLOOD.dropScale, false,
        0, 0, black ? RenderConfig.BLOOD.blackFlightGlow : 0,
        black ? RenderConfig.BLOOD.glowIntFlight : 0.0);
    }

// on landing, write the drop as a persisted SPLAT tile decoration (cell + sub-cell offset)
  override public function onDeath():Void
    {
      var colF = x / CityConfig.CELL + CityConfig.GRID / 2 - 0.5;
      var rowF = z / CityConfig.CELL + CityConfig.GRID / 2 - 0.5;
      var col = Math.round(colF), row = Math.round(rowF);
      var t = Const.TILE_SIZE;
      var dx = Std.int((colF - col) * t);
      var dy = Std.int((rowF - row) * t);
      var scale = Const.round2(RenderConfig.BLOOD.scaleMin +
        (RenderConfig.BLOOD.scaleMax - RenderConfig.BLOOD.scaleMin) * Math.random());
      var angle = Const.round2(2 * Math.PI * Math.random());
      // hit a wall mid-arc: stand the splat upright on the struck face (like a bullet hole). face =
      // the side whose neighbour toward the last open cell is actually exposed; tie -> dominant axis
      if (hitWall)
        {
          var ddx = prevCol - col, ddy = prevRow - row;
          var xOpen = ddx != 0 && game.area.canSeeThrough(col + (ddx > 0 ? 1 : -1), row);
          var zOpen = ddy != 0 && game.area.canSeeThrough(col, row + (ddy > 0 ? 1 : -1));
          var dir = (xOpen && zOpen) ? render.world.Geom.faceToward(ddx, ddy)
            : xOpen ? (ddx > 0 ? 2 : 3)
            : zOpen ? (ddy > 0 ? 0 : 1)
            : render.world.Geom.faceToward(ddx, ddy);
          game.area.addTileDecoration(col, row, {
            layerID: game.area.getTileset().splatLayerID,
            icon: { row: iy, col: ix },
            face: dir,
            height: y,
            dx: dx,
            dy: dy,
            scale: scale,
            angle: angle,
            tag: 'SPLAT',
          });
          return;
        }
      // flat ground splat
      if (!game.area.isWalkable(col, row))
        return;
      game.area.addTileDecoration(col, row, {
        layerID: game.area.getTileset().splatLayerID,
        icon: { row: iy, col: ix },
        dx: dx,
        dy: dy,
        scale: scale,
        angle: angle,
        tag: 'SPLAT',
      });
    }
}
