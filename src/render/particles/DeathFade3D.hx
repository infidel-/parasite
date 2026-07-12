package render.particles;

import three.Three;
import render.RenderConfig;

// a dying actor's last sprite: spins a full turn about the vertical, topples flat onto the floor
// (firing the item-drop sound as it lands), then fades out while the corpse body decal fades
// in beneath it — the crossfade that replaces the hard cut from actor to corpse. purely
// visual; commits nothing on death
class DeathFade3D extends Particle3D {
  static inline var SPIN_MS = RenderConfig.BASE_MS * 3.0;   // full spin about Y (0..2PI)
  static inline var FALL_MS = RenderConfig.BASE_MS * 2.0;   // topple upright -> flat
  static inline var FADE_MS = RenderConfig.BASE_MS * 1.0;   // ease opacity out once landed

  var tex:CanvasTexture;
  var x:Float; var y:Float; var z:Float;                    // feet-planted world pos (y = floorY)
  var scale:Float;
  var startOp:Float;
  var op:Float;
  var onLand:Void->Void;                                    // item-drop sound, fired once on landing
  public var onLandExtra:Void->Void = null;                 // extra landing hook (corpse body fade-in), bound after spawn
  public var targetSpin:Float = Math.PI * 2;                // total Y-spin; ends flat facing this yaw (= the corpse's resting yaw, set after spawn)
  public var offx:Float = 0.0;                              // feet drift toward the corpse's resting offset over the topple
  public var offz:Float = 0.0;
  var age:Float = 0.0;                                      // ms elapsed (anim-speed scaled)
  var landed:Bool = false;

  public function new(tex:CanvasTexture, x:Float, y:Float, z:Float, scale:Float, op:Float, onLand:Void->Void)
    {
      super();
      this.tex = tex;
      this.x = x;
      this.y = y;
      this.z = z;
      this.scale = scale;
      this.startOp = op;
      this.op = op;
      this.onLand = onLand;
    }

// advance the spin -> topple -> fade clock; fire the landing sound once; die after the fade
  override public function tick(dtMs:Float):Bool
    {
      age += dtMs * RenderConfig.ANIM_SPEED;
      // landing: the moment the topple completes, play the item-drop sound once
      if (!landed &&
          age >= SPIN_MS + FALL_MS)
        {
          landed = true;
          if (onLand != null)
            onLand();
          // the corpse body only starts fading in now, once the dying sprite has fallen flat
          if (onLandExtra != null)
            onLandExtra();
        }
      // opacity stays full through spin + fall, then eases out
      var fadeAge = age - (SPIN_MS + FALL_MS);
      if (fadeAge > 0)
        op = startOp * (1 - fadeAge / FADE_MS);
      return age < SPIN_MS + FALL_MS + FADE_MS;
    }

// draw the toppling ghost: a full spin about Y through the spin phase, then tip flat
  override public function draw(p:Paint3D):Void
    {
      var spinY = Math.min(1.0, age / SPIN_MS) * targetSpin;
      var fall = Math.max(0.0, Math.min(1.0, (age - SPIN_MS) / FALL_MS));
      // drift the feet toward the corpse's resting offset as it topples, so the ghost lands
      // exactly where the body decal lies
      p.sprites.paintTopple({
        x: x + offx * fall,
        y: y,
        z: z + offz * fall,
        tex: tex,
        op: op,
        scale: scale,
        spinY: spinY,
        fall: fall,
      });
    }
}
