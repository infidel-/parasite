package render;

import three.Three;
import js.Browser;

// the half of the shader pre-warm that is not about any one area kind. the per-kind halves live next
// to the builders they mirror — render.CityWarm, render.sewer.SewerWarm, render.facility.FacilityWarm
// — because a warm scene is a copy of a real build and silently rots when the build moves; keeping
// the two in one directory is what makes the drift visible. render.View owns only the ORDER they run
// in (warmup at boot, warmKind on first entry to a kind) and the reporting around them
class Warmup
{
  public static var hold:Array<Scene> = []; // every warm scene ever built, retained so its materials' programs stay cached

// the ACTOR LAYER and the on-demand effects every real scene carries, parked in `g` so a kind's warm
// compiles them under ITS light counts: NUM_DIR / NUM_POINT / NUM_SPOT_LIGHTS are in every program
// key, basics included, so the city's warm covers none of them for a moonless kind. Measured on the
// first underground-lab entry: the billboard pool's MeshStandard and the player ring compiled on the
// entry frame. The muzzle-flash pool comes first because Actors adds it to every scene
  public static function actorLayer(g:Group, camera:PerspectiveCamera):Void
    {
      new render.particles.MuzzleLights(g);
      for (m in render.particles.GasCloud3D.warmupMeshes()) // gas puffs (explicit front/back MeshStandard)
        g.add(m);
      for (m in render.particles.Sprites.warmupMeshes())    // actor billboards (MeshStandard + map/emissiveMap)
        g.add(m);
      // beams + hit sparks: spawn once via the REAL code so the exact materials get built (no config to
      // drift). streak (no map) + glow (map) cover both MeshBasic variants; beams share streak's program
      var beams = new render.particles.Beams(g);
      beams.quad(0, 0, 0, 1, 0, 0, 0xffffff, 1);
      var sparks = new render.particles.Sparks(g, camera);
      sparks.streak(0, 0, 0, 1, 0, 0, 1, 0.2, 0xffffff, 1);
      sparks.glowQuad(0, 0, 0, 1, 0xffffff, 1);
      // the grown props' writhing core: a plain additive quad EXCEPT for its uv-disturbance patch,
      // which carries a customProgramCacheKey of its own
      for (m in render.actors.PropFX.warmupMeshes())
        g.add(m);
      // and the player's marker ring, View's own
      g.add(render.View.playerRing());
    }

// three renders a transparent DoubleSide (non-forceSinglePass) material as TWO single-side passes
// (side FrontSide then BackSide), each its own program; compileAsync on the DoubleSide material
// compiles a doubleSided program the runtime never uses (see the gas entry in docs/3d-render.md).
// so for every such material in the scene, add explicit FrontSide + BackSide clone meshes so BOTH
// real programs get cached instead of recompiling on the first render. the clones are never drawn to
// any purpose — compileAsync walks the whole scene, and being IN it is the entire job
  static function splitDoubleSided(sc:Scene):Void
    {
      var quad = new PlaneGeometry(1, 1);
      var seen = new haxe.ds.ObjectMap<Dynamic, Bool>();
      var clones:Array<Object3D> = [];
      sc.traverse(function(o:Object3D)
        {
          var mat:Dynamic = untyped o.material;
          if (mat == null)
            return;
          // USE_INSTANCING is a program DEFINE, so a clone hung on a plain Mesh warms a different
          // program from the one an InstancedMesh source actually draws — three reads the flag off the
          // OBJECT, not the material. carry the source's kind across or the split misses every
          // instanced one, which underground and out at the compound is most of them
          var inst:Bool = untyped o.isInstancedMesh == true;
          var mats:Array<Dynamic> = Std.isOfType(mat, Array) ? mat : [ mat ];
          for (mm in mats)
            {
              if (mm == null
                || seen.exists(mm))
                continue;
              seen.set(mm, true);
              if (mm.transparent == true
                && mm.side == THREE.DoubleSide
                && mm.forceSinglePass != true)
                for (side in [ THREE.FrontSide, THREE.BackSide ])
                  {
                    var c = mm.clone();
                    c.side = side;
                    // three's Material.copy() lists neither onBeforeCompile nor
                    // customProgramCacheKey — render.world.VisionMask.patch carries the same
                    // obituary, found live on a ghost prop. so a clone of a mask-patched material
                    // warms the UNPATCHED key: the wrong program cached AND the right one still
                    // missing. carry both across. safe to SHARE rather than re-patch, because the
                    // hooks only assign shared static uniforms and the key closures return a string
                    // that does not depend on their receiver. own properties only — three keeps a
                    // default of each on the prototype, and taking those would key on nothing
                    if (untyped mm.hasOwnProperty('onBeforeCompile'))
                      untyped c.onBeforeCompile = mm.onBeforeCompile;
                    if (untyped mm.hasOwnProperty('customProgramCacheKey'))
                      untyped c.customProgramCacheKey = mm.customProgramCacheKey;
                    clones.push(inst ? new InstancedMesh(quad, c, 1) : new Mesh(quad, c));
                  }
            }
        });
      for (c in clones)
        sc.add(c);
    }

// compile every program in a throwaway warm scene, then RENDER it once. four things this encodes,
// each measured rather than reasoned:
//   the DoubleSide split above has to run FIRST, and for EVERY kind — it used to sit inline in the
//   city warm and cover the city alone, which left the tunnels' shaft cone and the facility's lamp
//   cone and window glow relying on the trailing render to catch them, and that render only sees the
//   frustum;
//   the composer's INTERMEDIATE target has to be bound BEFORE the compile — the game renders scene ->
//   a srgb-linear target and OutputPass converts to sRGB, and the bound target's colour space is
//   baked into a program's cacheKey, so compiling against the default sRGB framebuffer warms programs
//   the game never asks for and every real one still compiles on entry;
//   compileAsync walks the WHOLE scene, not the frustum, so no camera framing is needed and the
//   driver gets the lot in parallel (KHR_parallel_shader_compile is present);
//   and compileAsync does NOT reach the shadow-map depth materials — only a real pass compiles those,
//   which is what the render at the end is for.
// `between` runs between two compile passes, for a scene that must also warm a second light-count
// variant. the scene is retained in `hold`: three frees a program only on material.dispose(), so
// holding the materials holds their programs. geometry is deliberately NOT disposed — several of
// these are shared static models and particle quads, and disposing them would break the real build
  public static function compile(renderer:WebGLRenderer, camera:PerspectiveCamera, sc:Scene,
    ?between:Void->Void):Dynamic
    {
      splitDoubleSided(sc);
      // minimal composer (RenderPass + bloom + output) to warm the always-on post-FX programs; GTAO
      // and the shockwave pass are disabled/on-demand and compile on toggle regardless
      var comp = new EffectComposer(renderer);
      comp.addPass(new RenderPass(sc, camera));
      comp.addPass(new UnrealBloomPass(
        new Vector2(Browser.window.innerWidth, Browser.window.innerHeight),
        RenderConfig.BLOOM_STRENGTH, RenderConfig.BLOOM_RADIUS, RenderConfig.BLOOM_THRESHOLD));
      comp.addPass(new OutputPass());
      renderer.setRenderTarget(comp.renderTarget1);
      var p:Dynamic = renderer.compileAsync(sc, camera);
      if (between != null)
        p = p.then(function(_)
          {
            between();
            return renderer.compileAsync(sc, camera);
          });
      return p.then(function(_)
        {
          renderer.setRenderTarget(null);
          // nothing frustum-culled for this one render: compileAsync compiles but does not LINK on
          // ANGLE (that waits for the first draw), and a map uploads only when something draws with
          // it — so a warm that only drew the frustum left both to the first real frame they showed in
          var culled:Array<Object3D> = [];
          sc.traverse(function(o:Object3D)
            {
              if (o.frustumCulled)
                {
                  culled.push(o);
                  o.frustumCulled = false;
                }
            });
          comp.render();
          for (o in culled)
            o.frustumCulled = true;
          comp.dispose();
          hold.push(sc);
          return null;
        });
    }
}
