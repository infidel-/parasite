package render.lab;

import three.Three;
import render.RenderConfig;
import render.Textures;
import render.particles.FlameLights;
import render.particles.Sprites;
import render.world.VisionMask;

// one burner's flame: where its barrel's rim stands in the world, and its own flicker phase
typedef LabFlame = {
  x:Float,
  y:Float,
  z:Float,
  phase:Float,
};

// every burner's quads, and the clock they breathe on
typedef LabFlameSet = {
  flames:Array<LabFlame>,
  quads:Array<Mesh>,          // three a burner: glow, outer flame, inner flame
  t:Float,                    // flicker clock, ms scaled by ANIM_SPEED (FlameLights.flicker's unit)
};

// the bunsen burners' gas flames: the burning barrel's own FX (render.actors.LampShadows
// .drawFlameBody) burning blue — two frontal flame quads breathing on their own beats over a soft
// additive glow, fixed-yaw and leaned back by Sprites.TILT like every world-anchored FX, the flame's
// base pinned to the rim through the lean.
//
// NOT the barrel's Sparks pool: that one is reset and refilled by arbitrary callers every frame
// (render.actors.PropFX's header records why fixed quads do not belong in it), and these never move,
// so three quads a burner are made once here and only their size, sway and opacity change. The
// flame's SHAPE is the barrel's own sprite worn as an ALPHA MAP (its green channel) under a flat
// blue, because the sprite is painted orange and a tint can only multiply it darker. VisionMask
// patches every material, so a burner out of sight darkens with the bench it stands on
class LabFlames
{
  static var flameTex:Texture = null;
  static var glowTex:Texture = null;

// the quads for every flame the interior planned
  public static function build(scene:Scene, flames:Array<LabFlame>):LabFlameSet
    {
      if (flameTex == null)
        {
          flameTex = Textures.loadTexture(RenderConfig.TEXTURES.flame, 'wall');
          flameTex.wrapS = flameTex.wrapT = THREE.ClampToEdgeWrapping;
          glowTex = Textures.makeRectGlowGradient(0.30);
        }
      var set:LabFlameSet = {
        flames: flames,
        quads: [],
        t: 0.0,
      };
      for (f in flames)
        for (k in 0...3)
          {
            var m = new Mesh(new PlaneGeometry(1, 1), VisionMask.patch(new MeshBasicMaterial({
              color: (k == 2 ? LabStyle.FLAME_HOT : LabStyle.FLAME_TIP),
              alphaMap: (k == 0 ? glowTex : flameTex),
              transparent: true,
              depthWrite: false,
              side: THREE.DoubleSide,
              blending: untyped THREE.AdditiveBlending,
            })));
            m.rotation.set(-Sprites.TILT, 0, 0);
            m.renderOrder = Sprites.ORD_FIXTURE;
            m.frustumCulled = false;
            scene.add(m);
            set.quads.push(m);
          }
      return set;
    }

// one burner at the origin, for render.lab.LabWarm: the glow and flame programs
  public static function warm(scene:Scene):Void
    {
      tick(build(scene, [{
        x: 0.0,
        y: 0.0,
        z: 0.0,
        phase: 0.0,
      }]), 0.0);
    }

// breathe every flame: the barrel's layering and flicker, at the burner's scale
  public static function tick(set:LabFlameSet, dtMs:Float):Void
    {
      set.t += dtMs * RenderConfig.ANIM_SPEED;
      for (i in 0...set.flames.length)
        {
          var f = set.flames[i];
          var fl = FlameLights.flicker(set.t, f.phase);
          var fl2 = FlameLights.flicker(set.t, f.phase + 2.3);
          // the soft halo, centred a little above the rim
          var g = set.quads[i * 3];
          g.position.set(f.x, f.y + LabStyle.FLAME_H * 0.25, f.z);
          g.scale.set(LabStyle.FLAME_GLOW_W, LabStyle.FLAME_GLOW_W, 1);
          opacity(g, LabStyle.FLAME_GLOW_A * (0.6 + 0.4 * fl));
          // outer flame: cooler, bigger, a gentle bob; inner: hotter, shorter, a faster one
          layer(set.quads[i * 3 + 1], f, LabStyle.FLAME_H * (0.8 + 0.35 * fl),
            LabStyle.FLAME_W * (0.75 + 0.4 * fl), Math.sin(set.t * 0.012 + f.phase) * 0.05,
            LabStyle.FLAME_A * (0.5 + 0.4 * fl));
          layer(set.quads[i * 3 + 2], f, LabStyle.FLAME_H * 0.62 * (0.85 + 0.4 * fl2),
            LabStyle.FLAME_W * 0.6 * (0.7 + 0.5 * fl2), Math.sin(set.t * 0.02 + f.phase * 1.7) * 0.06,
            LabStyle.FLAME_A * (0.6 + 0.4 * fl2));
        }
    }

// one flame quad of height h and width w, its BASE on the rim through the lean (Sparks.flameQuad's
// own correction), bobbing by `bob` of its height
  static function layer(m:Mesh, f:LabFlame, h:Float, w:Float, bob:Float, op:Float):Void
    {
      var half = h * 0.5;
      m.position.set(f.x, f.y + half + bob * h - half * (1 - Math.cos(Sprites.TILT)),
        f.z - half * Math.sin(Sprites.TILT));
      m.scale.set(w, h, 1);
      opacity(m, op);
    }

  static inline function opacity(m:Mesh, op:Float):Void
    {
      // Dynamic: a Mesh's material, which the three extern types as Dynamic on Object3D — it is the
      // MeshBasicMaterial built above
      var mat:Dynamic = m.material;
      mat.opacity = op;
    }
}
