package render.particles;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import game.Game;
import entities.Entity;

// choir silent-scream pulse: a ghostly additive hemisphere dome expanding from the caster cell
// to the effect radius while fading out. the screen-space shockwave ripple (render.View's scream
// pass) tracks the same wave front through cx/cy/cz + radius()/strength(). actors the front
// sweeps over get the default hit shake (via onTouch). 3D port of ParticleSilentScream
class ScreamPulse3D extends Particle3D {
  public var cx(default, null):Float;                   // dome center world x
  public var cy(default, null):Float;                   // dome base world y (floor)
  public var cz(default, null):Float;
  public var done(default, null):Bool = false;          // finished (the view then drops its ripple slot)
  static var domeGeo:SphereGeometry = null;             // shared unit hemisphere (scale is per-instance)
  var onTouch:Entity->Void;                             // fired once per actor when the front reaches it
  var group:Group;
  var mesh:Mesh;
  var mat:Dynamic;
  var t:Float = 0;                                      // pulse progress 0..1
  var touch:Array<{ e:Entity, d2:Float }> = [];         // in-radius actors by distance²; popped as the front passes

  public function new(group:Group, cx:Float, cy:Float, cz:Float, game:Game, onTouch:Entity->Void)
    {
      super();
      this.group = group;
      this.cx = cx;
      this.cy = cy;
      this.cz = cz;
      this.onTouch = onTouch;
      var S = RenderConfig.SCREAM;
      // collect every actor the front can reach once, sorted by distance: the radius grows
      // monotonically, so the tick just pops the head as the front sweeps past it. the caster
      // (center-cell occupant) is skipped
      var cc = CityConfig.worldToCell(cx, cz);
      var maxR = S.radiusCells * CityConfig.CELL;
      for (ai in game.area.getAllAI())
        if (!(ai.x == cc.col && ai.y == cc.row))
          addTouch(ai.entity, ai.x, ai.y, maxR * maxR);
      if (!(game.playerArea.x == cc.col && game.playerArea.y == cc.row))
        addTouch(game.playerArea.entity, game.playerArea.x, game.playerArea.y, maxR * maxR);
      touch.sort(function(a, b) return a.d2 < b.d2 ? -1 : 1);
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
      // unit hemisphere, scaled to the live radius each tick (squashed to a wide sonic dome);
      // one shared geometry across casts — only the material carries per-instance uniforms
      if (domeGeo == null)
        domeGeo = new SphereGeometry(1, S.domeSegs, Std.int(S.domeSegs / 2),
          0, Math.PI * 2, 0, Math.PI / 2);
      mesh = new Mesh(domeGeo, mat);
      mesh.position.set(cx, cy, cz);
      group.add(mesh);
    }

// queue an entity for the wave-front touch beat if the wave can reach its cell
  function addTouch(e:Entity, col:Int, row:Int, max2:Float):Void
    {
      if (e == null)
        return;
      var w = CityConfig.cellToWorld(col, row);
      var dx = w.x - cx;
      var dz = w.z - cz;
      var d2 = dx * dx + dz * dz;
      if (d2 <= max2)
        touch.push({ e: e, d2: d2 });
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
      // shake each actor once as the wave front sweeps over it (visual beat only — the gameplay
      // effect already landed at cast)
      var r2 = r * r;
      while (touch.length > 0 &&
             touch[0].d2 <= r2)
        onTouch(touch.shift().e);
      return true;
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

// kill the pulse early (area exit): drop the dome now instead of waiting for a tick that
// never comes during the outro
  public function kill():Void
    {
      if (!done)
        onDeath();
    }

// drop the dome mesh and flag the ripple slot free (the geometry is shared — keep it)
  override public function onDeath():Void
    {
      done = true;
      group.remove(mesh);
      untyped mat.dispose();
    }
}
