package render;

import three.Three;
import citygen.CityGen;
import citygen.CityConfig;
import render.Models.ModelVariant;
import citygen.CityModel.Building;
import render.world.Geom;

// the BOOT warm scene: a throwaway city carrying every program the streets need, plus the on-demand
// effects that are shared across every kind and have to be warmed SOMEWHERE. built by the real
// builders, so the material / instancing / light-count set matches the game exactly and the match is
// by construction rather than by bookkeeping.
// it lives here rather than in render.View for the reason render.Warmup records — a warm scene is a
// copy of a real build — and next to render.CityArea because that is where the city kind lives (the
// other three kinds are each in a package of their own).
// covers the full static city + post-FX + gas + actor sprites + beams/sparks (ring/tactical share
// those programs — blending is render state, not a shader define).
// NOT covered anywhere, on purpose: silent-scream (its ctor needs live area state) and occlusion
// ghosts (compile on first fade) — both cheap one-off first-use hitches, warmed later via their own
// warmupMeshes if ever noticed
class CityWarm
{
  // buildings kept per signature by `representatives`: one would do for the programs; the second is
  // margin for a roof/parapet role or wall pairing the signature does not spell out
  static inline var REPS = 2;

// build the throwaway city, park the shared effects in it and start the compile. returns the promise
// AND the stamp taken the moment the compile was issued: everything before that point was one
// blocked main thread, and the boot screen sits there for exactly that long, so render.View reports
// the two halves apart
  public static function build(renderer:WebGLRenderer, camera:PerspectiveCamera, lampPool:Int):
    { tSync:Float, p:Dynamic }
    {
      var seed = 1;
      var city = CityGen.generate(seed);
      // same lamp pool as the real scene: NUM_SPOT_LIGHTS is part of the program key, so warming at a
      // different pool size would compile programs the game then never uses
      var bundle = SceneSetup.buildScene(renderer, city, lampPool); // base scene + fixed light pools + lamp cones
      var s = bundle.scene;
      World.build(s, city, seed, null, WARM);              // all lit world geometry (instanced MeshStandard) over representative buildings; no audit — throwaway city
      // also warm the downtown style's materials (glass facade/back, curtain windows, mechanical
      // penthouse, downtown ground) on a throwaway downtown city, parked in the same warm scene, so
      // the first high-density (AREA_CITY_HIGH) entry reuses the cached programs instead of recompiling
      var dtCity = CityGen.generate(seed, citygen.CityProfile.Profiles.forArea(AREA_CITY_HIGH));
      World.build(s, dtCity, seed, render.world.AreaStyle.forArea(AREA_CITY_HIGH), WARM_NO_GROUND);
      // and the slums style (house walls/windows/doors, shingle gable, slums ground, the dead-lawn
      // cutout) on a throwaway low-density city — a NEW GAME starts in AREA_CITY_LOW, so this is the
      // first city most sessions ever build
      var slCity = CityGen.generate(seed, citygen.CityProfile.Profiles.forArea(AREA_CITY_LOW));
      World.build(s, slCity, seed, render.world.AreaStyle.forArea(AREA_CITY_LOW), WARM_NO_GROUND);
      // the downtown lamp (street-lamp2) is a distinct PBR material program from the residential lamp
      // buildScene already compiled — instance one into the warm scene so the first downtown entry
      // reuses it instead of recompiling on the first frame
      Models.instanced(s, RenderConfig.MODELS.streetLamp2, [{ x: 0.0, z: 0.0, yaw: 0.0 }], CityConfig.CELL * 1.6, SOLID);
      // on-demand effects never present at static-build time: park throwaway instances so they warm too
      var g = new Group();
      s.add(g);
      // the muzzle-flash point-light pool the real build adds via Actors: it sits in the scene forever at
      // intensity 0 so NUM_POINT_LIGHTS is constant, and that count is baked into EVERY lit material's
      // program — so the warm scene must carry it or every MeshStandard program compiles at the wrong
      // light count and recompiles on entry. this is the 5-light count (every non-barrel city); the
      // 10-light AREA_CITY_LOW variant is warmed by the second compile pass below (FlameLights added)
      // the actor billboards, the gas, the beams and sparks, the grown props' core and the player ring
      // — see Warmup.actorLayer. the grown props' core is warmed here for the first habitat entry
      Warmup.actorLayer(g, camera);
      // park the moon's shadow box over the city so the composer pass below actually runs the shadow
      // depth pass — otherwise the box sits at world origin, the city-wide shadow caster falls outside it,
      // no depth material renders, and the position-only shadow programs compile on the first real frame
      var span = CityConfig.CELL * CityConfig.GRID;
      SceneSetup.fitMoon(bundle.moon, new Vector3(span / 2, 0, span / 2));
      // TWO compile passes: NUM_POINT_LIGHTS is baked into every lit material's program, and low-tier
      // cities (AREA_CITY_LOW, where a NEW GAME starts) carry the barrel FlameLights pool -> 10 point
      // lights vs 5 everywhere else. warm the 5-count first, then add FlameLights and warm the
      // 10-count, so both variants are cached and neither the new-game start nor any later city
      // recompiles on entry
      var p = Warmup.compile(renderer, camera, s, function() new render.particles.FlameLights(g));
      return {
        tSync: haxe.Timer.stamp(),
        p: p,
      };
    }

// a warm city's buildings: the first REPS of each signature, which is every Building field a builder
// turns into a different material, mesh kind or texture set. the city itself stays whole (tiles,
// neighbours), only fewer of its buildings are built — measured on the boot warm, the three cities'
// thousands of materials were three's per-material program setup as much as the builders' own time.
// THE ACCEPTANCE TEST IS THE `__progs()` KEY SET: identical at boot to a full warm, and no new key on
// the first entry to each city style. re-run it whenever a builder starts reading another field
  public static function representatives(bs:Array<Building>):Array<Building>
    {
      var seen = new Map<String, Int>();
      var out = [];
      for (b in bs)
        {
          var fi = Geom.frontInfo(b);
          var k = '${b.facade}|${b.shop}|${b.shopOpen}|${b.roof}|${b.buriedH > 0}|${b.roofPenthouse}|' +
            '${b.winForce != null}|${b.winBlock != null}|${b.winInset > 0}|${b.skipWindowFloor >= 0}|' +
            '${fi.store}|${fi.small}|${Geom.noBackWalls(b)}';
          var n = seen.exists(k) ? seen.get(k) : 0;
          if (n >= REPS)
            continue;
          seen.set(k, n + 1);
          out.push(b);
        }
      return out;
    }
}
