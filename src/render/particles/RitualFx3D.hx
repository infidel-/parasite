package render.particles;

import citygen.CityConfig;
import game.Game;
import render.RenderConfig;
import render.world.WorldCtx;

// one stage of the Metamorphosis II ritual (cult.ordeals.MetamorphosisPhaseII) round the cell it is
// channelled on: cult-pink sinews spiral in from the habitat, a column of glow rises where they meet
// and a ring of embers spreads across the floor. each stage is wider and brighter, the third bleeds
// as the Heart tears up. the place quakes as the sinews meet. the stage's vision opens when it ends
// (onDone)
class RitualFx3D extends Particle3D {
  // durations and beats, all in BASE_MS units
  static inline var RITUAL_T = 14.0;    // the whole stage
  static inline var KNIT_T = 7.0;       // the sinews reach the centre by
  static inline var RING_T = 6.0;       // the closing ring's spread
  // shapes, in cells
  static inline var REACH = 1.5;        // the sinews' starting radius, plus half a cell per stage
  static inline var COLUMN = 4;         // glows stacked in the rising column
  static inline var RING_SPREAD = 2.5;  // the ring's final radius, plus half a cell per stage
  static inline var RING_Y = 0.15;      // the ring's lift off the floor, over the habitat's growths
  static inline var RING_EMBERS = 36;   // embers drawing it, each a tangent dash
  static inline var BLOOD_DROPS = 18;   // the burst the Heart bleeds on the last stage
  static inline var QUAKE = 0.2;        // the camera quake as the sinews meet, of the full one, per stage
  // colours
  static inline var CULT_COL = 0xe0609a;
  static inline var SINEW_COL = 0xd04a78;
  static inline var HEART_COL = 0xff8a3a;

  var game:Game;
  var particles:Particles3D;            // where the last stage's blood burst goes
  var stage:Int;                        // 1..3
  var onDone:Void -> Void;              // opens the stage's vision
  var col:Int;
  var row:Int;
  var cx:Float;                         // the cell's centre, world
  var cz:Float;
  var floor:Float;
  var t:Float = 0.0;
  var knit:Bool = false;                // the sinews have met: quaked, and bled on the last stage

  public function new(game:Game, particles:Particles3D, col:Int, row:Int, stage:Int, onDone:Void -> Void)
    {
      super();
      this.game = game;
      this.particles = particles;
      this.stage = stage;
      this.onDone = onDone;
      this.col = col;
      this.row = row;
      var w = CityConfig.cellToWorld(col, row);
      cx = w.x;
      cz = w.z;
      floor = WorldCtx.floorY(col, row);
    }

  override public function tick(dtMs:Float):Bool
    {
      t += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      if (!knit &&
          t >= KNIT_T)
        {
          knit = true;
          game.scene.view3d.playQuake(QUAKE * stage);
          if (stage == 3)
            {
              var ic = Const.bloodIcon('red');
              BloodDrop3D.burst(particles, game, col, row, 0, 0, ic.row, ic.col, BLOOD_DROPS);
            }
        }
      return t < RITUAL_T;
    }

  override public function draw(paint:Paint3D):Void
    {
      var cell = CityConfig.CELL;
      var sinews = 16 + stage * 8;

      // sinews spiralling in from the habitat and climbing as they close
      var p = Math.min(1.0, t / KNIT_T);
      if (p < 1)
        for (i in 0...sinews)
          {
            var a = i / sinews * Math.PI * 2 + p * (2.0 + stage * 0.5);
            var r = (REACH + stage * 0.5) * cell * (1 - p * p);
            var y = floor + cell * (0.1 + 0.6 * p * ((i * 37) % sinews) / sinews);
            paint.sparks.streak(cx + Math.cos(a) * r, y, cz + Math.sin(a) * r,
              -Math.cos(a), 0.3, -Math.sin(a), cell * (0.25 + 0.5 * (1 - p)), cell * 0.1,
              SINEW_COL, Math.min(1.0, 4 * p) * (1 - p * p));
          }

      // a column of glow rising where they met, pulsing like a heartbeat
      var u = (t - KNIT_T * 0.6) / (RITUAL_T - KNIT_T * 0.6);
      if (u > 0)
        {
          var fade = Math.sin(Math.PI * Math.min(1.0, u));
          var beat = 0.75 + 0.25 * Math.sin(t * 2.0);
          var colr = (stage == 3 ? HEART_COL : CULT_COL);
          for (k in 0...COLUMN)
            paint.sparks.glowQuad(cx, floor + cell * (0.3 + k * 0.45 * (0.5 + u)), cz,
              cell * (0.6 + 0.25 * stage) * (1 - k * 0.15), colr,
              (0.35 + 0.1 * stage) * fade * beat * (1 - k * 0.2));
        }

      // a ring of embers spreading across the floor as the stage closes: additive streaks, since a
      // lit floor ring drowns in the habitat's flesh (OrganFx3D)
      var v = (t - (RITUAL_T - RING_T)) / RING_T;
      if (v > 0)
        {
          var r = (0.4 + (RING_SPREAD + stage * 0.5) * v) * cell;
          for (i in 0...RING_EMBERS)
            {
              var a = i / RING_EMBERS * Math.PI * 2;
              paint.sparks.streak(cx + Math.cos(a) * r, floor + RING_Y, cz + Math.sin(a) * r,
                -Math.sin(a), 0, Math.cos(a), cell * 0.4, cell * 0.1, CULT_COL, 1.0 - v * v);
            }
        }
    }

// the stage is over: show its vision
  override public function onDeath():Void
    {
      onDone();
    }
}
