package render.sewer;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.Textures;
import render.LightCone.ConeSet;
import render.particles.LampPost;
import render.sewer.SewerModel.Sewer;
import render.world.VisionMask;

// weak bracketed lamps along the tunnel walls — the lighting BETWEEN the junctions. SewerModel only
// puts a lamp on a 3x3 corridor corner or intersection (plus one per exit), so a whole run of
// corridor had no light source of its own; these fill it with something dim, unreliable and cheap.
//
// there is no model and no art. a fixture is two quads on the wall face — an additive glow whose
// colour is pushed above 1 so it clears the sewer bloom threshold, over a soot smudge that also
// serves as the DEAD lamp's whole appearance. both are one InstancedMesh, so the level pays two draw
// calls however many lamps it has.
//
// everything else comes free from the city rig: a working fixture becomes a LampPost, so it competes
// for the shared spotlight pool (render.particles.LampLights) and therefore casts fake actor shadows
// (render.actors.LampShadows), and a non-zero phase is all LampLights and CastShadows need to make
// it sputter and to drop its shadow while it is out. broken/flickering/steady is decided from the
// FACE hash, exactly as SceneSetup decides it from the lamp cell in the slums — no rng, nothing
// persisted, the same tunnel breaks the same lamps on every reload
class SewerLamps
{
  static inline var CELL = CityConfig.CELL;

// place the wall fixtures, build their two quad batches, and hand back the working ones as LampPosts
// (for the pool) plus the glow batch (for the per-frame LightCone.pulse). the glow goes in coneGroup
// so the debug 5 / Shift+5 keys price and hide it alongside the light shafts
  public static function build(scene:Scene, coneGroup:Object3D, m:Sewer):{ posts:Array<LampPost>, glow:ConeSet }
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var posts:Array<LampPost> = [];
      var housing:Array<Matrix4> = []; // every fixture, dead ones included
      var glow:Array<Matrix4> = [];    // the working ones only
      var phases:Array<Float> = [];
      var q = new Quaternion();
      var up = new Vector3(0, 1, 0);
      // placement is per 2x2 BLOCK, the idiom SewerGround explains at length: an independent per-face
      // coin flip deals visible runs, one fixture per block caps a run at two by construction. the
      // gate multiplies by however many faces the block actually offers, so per-FACE density stays
      // WALL_LAMP_PCT whether the block is a corner or an open hall. a 2x2 block tops out at 8
      // eligible faces (its four internal edges cancel two candidates each), so 12 * 8 = 96 never
      // saturates the gate
      for (brow in 0...Std.int((m.h + 1) / 2))
        for (bcol in 0...Std.int((m.w + 1) / 2))
          {
            var bc = bcol * 2;
            var br = brow * 2;
            // multipliers of its own, mixed: the raw hash combs the always-solid area border (see
            // SewerModel.mix), and these must not correlate with the decal or wall-variant rolls
            var hh = SewerModel.mix((bc * 19349663) ^ (br * 83492791));
            var faces = [];
            for (dr in 0...2)
              for (dc in 0...2)
                {
                  var col = bc + dc;
                  var row = br + dr;
                  if (col >= m.w ||
                      row >= m.h ||
                      !m.floor[row][col] ||
                      nearShaft(m, col, row))
                    continue;
                  for (dir in 0...4)
                    if (!SewerModel.isFloor(m, col + faceDC(dir), row + faceDR(dir)))
                      faces.push({ col: col, row: row, dir: dir });
                }
            if (faces.length == 0)
              continue;
            if (hh % 100 >= SewerStyle.WALL_LAMP_PCT * faces.length)
              continue;
            var f = faces[(hh >> 7) % faces.length];
            // a separate mixed word for the fate, so breaking a lamp does not correlate with which
            // face of the block took it. the phase floor keeps a "flickering" lamp off the exact 0
            // that both LampLights and LightCone.pulse read as the STEADY marker
            var h2 = SewerModel.mix(hh ^ 0x2545F491);
            var dead = h2 % 100 < SewerStyle.WALL_LAMP_BROKEN_PCT;
            var flick = !dead &&
              (h2 >> 11) % 100 < SewerStyle.WALL_LAMP_FLICKER_PCT;
            var phase = flick ? 0.05 + ((h2 >> 17) % 628) / 100 : 0.0;

            var x0 = f.col * CELL - half;
            var z0 = f.row * CELL - half;
            // the wall plane point + the normal pointing INTO the floor cell, matching SewerGeom.side's
            // four directions. yaw turns a +Z-facing PlaneGeometry onto that normal
            var px = x0 + CELL / 2, pz = z0 + CELL / 2;
            var nx = 0.0, nz = 0.0, yaw = 0.0;
            switch (f.dir)
              {
                case 0:
                  pz = z0;
                  nz = 1;
                  yaw = 0;
                case 1:
                  pz = z0 + CELL;
                  nz = -1;
                  yaw = Math.PI;
                case 2:
                  px = x0;
                  nx = 1;
                  yaw = Math.PI / 2;
                default:
                  px = x0 + CELL;
                  nx = -1;
                  yaw = -Math.PI / 2;
              }
            q.setFromAxisAngle(up, yaw);
            var eps = SewerStyle.DECAL_EPS;
            var one = new Vector3(1, 1, 1);
            var mtx = new Matrix4();
            // the soot sits nearer the wall than the glow, so the two never z-fight each other
            mtx.compose(new Vector3(px + nx * eps * 0.5, SewerStyle.WALL_LAMP_Y, pz + nz * eps * 0.5), q, one);
            housing.push(mtx);
            if (dead)
              continue;
            var gm = new Matrix4();
            gm.compose(new Vector3(px + nx * eps, SewerStyle.WALL_LAMP_Y, pz + nz * eps), q, one);
            glow.push(gm);
            phases.push(phase);
            // the bulb for the pool stands off the wall so its cone starts in open air, and it AIMS
            // far out along the same normal: from WALL_LAMP_Y the beam then rakes the walkway instead
            // of pooling at the fixture's own feet, which is what makes the tunnel throw long shadows.
            // col/row stay the FLOOR cell — that is what the pool gates player distance on
            posts.push({
              x: px + nx * SewerStyle.WALL_LAMP_OUT,
              z: pz + nz * SewerStyle.WALL_LAMP_OUT,
              y: SewerStyle.WALL_LAMP_Y,
              tx: px + nx * SewerStyle.WALL_LAMP_AIM,
              tz: pz + nz * SewerStyle.WALL_LAMP_AIM,
              color: SewerStyle.WALL_LAMP_COLOR, // a bad tube, not the sky coming down a manhole
              col: f.col,
              row: f.row,
              phase: phase,
              flick: 1.0,
              mul: SewerStyle.WALL_LAMP_MUL,
            });
          }

      // the soot/housing smudge: every fixture including the dead ones, and for a dead one it IS the
      // fixture. static — nothing about it changes once built
      // a smooth-cornered BOX, not the round glow: these read as a diffuser panel in a housing, and a
      // circular falloff on the 3:2 quad came out an ellipse
      var fade = Textures.makeRectGlowGradient();
      batch(scene, housing, SewerStyle.WALL_LAMP_HOUSING, new MeshBasicMaterial({
        color: 0x000000,
        transparent: true,
        opacity: SewerStyle.WALL_LAMP_SOOT,
        alphaMap: fade,
        depthWrite: false,
        side: THREE.FrontSide,
        polygonOffset: true,
        polygonOffsetFactor: -3, // proud of the wall decals at -2, which are proud of the grime at -1
        polygonOffsetUnits: -3,
      }));
      // the glow: additive, and its colour multiplied past 1 so the rendered texel clears
      // SewerStyle.BLOOM_THRESHOLD. this is the fixture's ONLY brightness source (there is no
      // emissive glb head down here), so dropping an instance from the pack turns the lamp fully off
      var mesh = batch(coneGroup, glow, 1.0, new MeshBasicMaterial({
        color: new Color(SewerStyle.WALL_LAMP_COLOR).multiplyScalar(SewerStyle.WALL_LAMP_GLOW),
        transparent: true,
        alphaMap: fade,
        depthWrite: false,
        side: THREE.FrontSide,
        blending: untyped THREE.AdditiveBlending,
      }));
      // BELOW the actors, unlike the light shafts this batch sits in. a shaft is a column of lit air
      // that an actor stands inside, so drawing it last and letting it tint them is right. a wall
      // fixture is a quad stuck on masonry BEHIND them — and since nothing in the sprite pool writes
      // depth, at the shafts' order it painted its bright core straight through anyone in front of it
      if (mesh != null)
        untyped mesh.renderOrder = render.particles.Sprites.ORD_FIXTURE;
      return {
        posts: posts,
        glow: { mesh: mesh, matrices: glow, phases: phases, on: [for (_ in glow) true] },
      };
    }

// does an overhead shaft already light this cell? tested against the lamp CELL rather than the
// shaft's drawn centre: an exit's cone is nudged half a cell south (SewerStyle.EXIT_LAMP_SOUTH), and
// the clearance radius swallows that. squared compare, the same form LampLights gates range with
  static function nearShaft(m:Sewer, col:Int, row:Int):Bool
    {
      var r = SewerStyle.WALL_LAMP_CLEAR;
      for (l in m.lamps)
        {
          var dc = l.col - col;
          var dr = l.row - row;
          if (dc * dc + dr * dr <= r * r)
            return true;
        }
      return false;
    }

// one InstancedMesh over the fixture quad scaled by `mul`, or null when there is nothing to place
// (an empty ConeSet draws nothing and pulse() no-ops on it)
  static function batch(parent:Object3D, mats:Array<Matrix4>, mul:Float, mat:MeshBasicMaterial):InstancedMesh
    {
      if (mats.length == 0)
        return null;
      var inst = new InstancedMesh(
        new PlaneGeometry(SewerStyle.WALL_LAMP_W * mul, SewerStyle.WALL_LAMP_H * mul),
        VisionMask.patch(mat), mats.length);
      for (i in 0...mats.length)
        inst.setMatrixAt(i, mats[i]);
      untyped inst.instanceMatrix.needsUpdate = true;
      // instances are spread over the level while three's coarse cull tests a boundingSphere built
      // from the geometry at the origin — the wrong place, so it pops the whole batch on zoom. one
      // cheap draw call regardless (same call LightCone makes)
      untyped inst.frustumCulled = false;
      parent.add(inst);
      return inst;
    }

// cell offsets of the neighbour a wall face looks at, matching SewerGeom.side's directions
// (0 = north edge, 1 = south, 2 = west, 3 = east)
  static inline function faceDC(dir:Int):Int
    return dir == 2 ? -1 : (dir == 3 ? 1 : 0);

  static inline function faceDR(dir:Int):Int
    return dir == 0 ? -1 : (dir == 1 ? 1 : 0);
}
