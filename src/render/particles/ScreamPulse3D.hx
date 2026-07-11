package render.particles;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import game.Game;
import entities.Entity;

// choir silent-scream pulse: a ghostly additive hemisphere dome expanding from the caster cell
// to the effect radius while fading out. the screen-space shockwave ripple (StreetView's scream
// pass) tracks the same wave front through cx/cy/cz + radius()/strength(). actors the front
// sweeps over get the default hit shake (via onTouch). 3D port of ParticleSilentScream
class ScreamPulse3D extends Particle3D {
  public var cx(default, null):Float;                   // dome center world x
  public var cy(default, null):Float;                   // dome base world y (floor)
  public var cz(default, null):Float;
  public var done(default, null):Bool = false;          // finished (the view then drops its ripple slot)
  var game:Game;
  var onTouch:Entity->Void;                             // fired once per actor when the front reaches it
  var group:Group;
  var mesh:Mesh;
  var mat:Dynamic;
  var t:Float = 0;                                      // pulse progress 0..1
  var ccol:Int;                                         // center cell (its occupant = the caster, never shaken)
  var crow:Int;
  var shaken:Map<Int,Bool> = new Map();                 // AI ids the front already shook
  var playerShaken:Bool = false;

  public function new(group:Group, cx:Float, cy:Float, cz:Float, game:Game, onTouch:Entity->Void)
    {
      super();
      this.group = group;
      this.cx = cx;
      this.cy = cy;
      this.cz = cz;
      this.game = game;
      this.onTouch = onTouch;
      var cc = CityConfig.worldToCell(cx, cz);
      ccol = cc.col;
      crow = cc.row;
      var S = RenderConfig.SCREAM;
      // white-noise dome (the ability IS "black noise"): screen-space TV static — every grain
      // cell re-rolls a hash on a quantized clock, so the shell reads as crawling interference
      // instead of a plain translucent sphere
      mat = new ShaderMaterial({
        transparent: true,
        depthWrite: false,
        side: THREE.DoubleSide,
        blending: untyped THREE.AdditiveBlending,
        uniforms: {
          color: { value: new Color(S.domeColor) },
          alpha: { value: 0.0 },
          time: { value: 0.0 },
          px: { value: S.noisePx },
        },
        vertexShader: '
void main() {
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}',
        fragmentShader: '
uniform vec3 color;
uniform float alpha;
uniform float time;
uniform float px;
float rand(vec2 co) {
  return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}
void main() {
  vec2 cell = floor(gl_FragCoord.xy / px);
  // per-cell phase: every grain re-rolls on its OWN staggered clock instead of the whole
  // screen flipping at once — crawling analog static, not a synchronized strobe
  float phase = rand(cell);
  float tq = floor(time + phase);
  float n = rand(cell + vec2(tq, tq * 7.0));
  gl_FragColor = vec4(color * n, alpha * n);
}',
      });
      // unit hemisphere, scaled to the live radius each tick (squashed to a wide sonic dome)
      mesh = new Mesh(new SphereGeometry(1, S.domeSegs, Std.int(S.domeSegs / 2),
        0, Math.PI * 2, 0, Math.PI / 2), mat);
      mesh.position.set(cx, cy, cz);
      group.add(mesh);
    }

// advance the pulse: grow the dome along the wave front and fade it out; die at end of life
  override public function tick(dtMs:Float):Bool
    {
      var S = RenderConfig.SCREAM;
      t += dtMs * RenderConfig.ANIM_SPEED / (RenderConfig.BASE_MS * S.lifeMult);
      if (t >= 1)
        return false;
      var r = radius();
      mesh.scale.set(r, r * S.domeSquash, r);
      mat.uniforms.alpha.value = S.domeAlpha * strength();
      mat.uniforms.time.value += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS * S.noiseRate;
      touchActors(r);
      return true;
    }

// shake each actor once as the wave front sweeps over it (visual beat only — the gameplay
// effect already landed at cast). the caster (center-cell occupant) is skipped
  function touchActors(r:Float):Void
    {
      var r2 = r * r;
      for (ai in game.area.getAllAI())
        {
          if (ai.entity == null ||
              shaken.exists(ai.id) ||
              (ai.x == ccol && ai.y == crow))
            continue;
          var w = CityConfig.cellToWorld(ai.x, ai.y);
          var dx = w.x - cx;
          var dz = w.z - cz;
          if (dx * dx + dz * dz > r2)
            continue;
          shaken.set(ai.id, true);
          onTouch(ai.entity);
        }
      if (!playerShaken &&
          !(game.playerArea.x == ccol && game.playerArea.y == crow))
        {
          var w = CityConfig.cellToWorld(game.playerArea.x, game.playerArea.y);
          var dx = w.x - cx;
          var dz = w.z - cz;
          if (dx * dx + dz * dz <= r2)
            {
              playerShaken = true;
              onTouch(game.playerArea.entity);
            }
        }
    }

// current wave-front radius (world units): fast start, braking hard toward the effect radius
// (ease-out, exponent = easePow; higher = stronger end slowdown)
  public function radius():Float
    {
      var k = 1 - Math.pow(1 - t, RenderConfig.SCREAM.easePow);
      return 0.05 + RenderConfig.SCREAM.radiusCells * CityConfig.CELL * k;
    }

// remaining pulse strength (1 -> 0); drives the dome alpha and the ripple amplitude
  public function strength():Float
    {
      return 1 - t;
    }

// drop the dome mesh and flag the ripple slot free
  override public function onDeath():Void
    {
      done = true;
      group.remove(mesh);
      untyped mesh.geometry.dispose();
      untyped mat.dispose();
    }
}
