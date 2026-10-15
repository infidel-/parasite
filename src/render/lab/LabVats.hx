package render.lab;

import three.Three;
import citygen.CityConfig;
import game.Game;
import objects.mission.CloneVat;
import render.Area3DTickOpts;
import render.Models;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.particles.LampPost;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the clone vats: every 2x3 objects.mission.CloneVat group the mission spawned, drawn as FIVE batches
// over one placement per group — the opaque frame, the clone floating in it, the clone heaped on its
// floor, the growth medium and the glass. Five because they are five materials drawn three ways: the
// fluid and the glass are transparent, the fluid drains by scaling its height, and a clone is hidden
// or shown per vat. Not an render.world.ObjModels row: six objects make one vat, and a row places a
// prop per object.
//
// THE DRAIN IS RENDER STATE. A group's `isFlushed` flips the turn the purge fires; the fluid then
// eases out over BASE_MS * LabStyle.VAT_DRAIN_MULT. The eased value lives in a map the AREA owns
// (LabArea.drain), keyed on the root object, so a rebuild halfway through (refreshObjects) picks it up
// where it was, and a fresh build seeds it from the saved flag, so a drained vat never replays
typedef LabVatSet = {
  roots:Array<CloneVat>,                 // each group's part 0, in placement order
  frame:Models.InstancedProp,
  clone:Models.InstancedProp,
  slumped:Models.InstancedProp,
  fluid:Models.InstancedProp,
  glass:Models.InstancedProp,
  posts:Array<LampPost>,                 // one green lamp before each vat's glass, faded by its drain
  drain:Map<Int,Float>,                  // root object ID -> eased drain, 0 full to 1 empty
  base:Array<Array<Matrix4>>,            // [clone, slumped, fluid] untouched placement matrices,
                                         // taken once each glb lands; null until then
  spill:InstancedMesh,                   // the slurry each vat leaves on the floor, spreading with
                                         // its drain (lab/floor-marks cell 8); null with no vats
  spillAt:Array<{ x:Float, z:Float, yaw:Float }>,
};

class LabVats
{
  static inline var CELL = CityConfig.CELL;
  static var _m = new Matrix4();
  static var _zero = new Matrix4().makeScale(0, 0, 0);

// the vats standing in the live area, and their lamps (pushed onto `posts`)
  public static function build(scene:Scene, game:Game, drain:Map<Int,Float>,
      posts:Array<LampPost>):LabVatSet
    {
      var roots = [];
      for (o in game.area.getObjects())
        if (o.type == 'clone_vat')
          {
            var v:CloneVat = cast o;
            if (v.vatPartIndex == 0)
              roots.push(v);
          }
      var set = place(scene, roots, drain);
      for (p in set.posts)
        posts.push(p);
      return set;
    }

// the five batches over `roots`, also the warm's entry with an empty list
  public static function place(scene:Scene, roots:Array<CloneVat>, drain:Map<Int,Float>):LabVatSet
    {
      var frame = [], axis = [], posts = [];
      for (v in roots)
        {
          if (!drain.exists(v.id))
            drain.set(v.id, v.isFlushed ? 1.0 : 0.0);
          // the footprint's centre is between its two columns and on its middle row; the cylinder
          // stands on the back 2x2's centre, VAT_AXIS north of it
          var c = CityConfig.cellToWorld(v.x, v.y + 1);
          var x = c.x + CELL / 2;
          frame.push({
            x: x,
            z: c.z,
            yaw: 0.0,
          });
          axis.push({
            x: x,
            z: c.z - LabStyle.VAT_AXIS,
            yaw: 0.0,
            y: LabStyle.VAT_GLASS_Y,
          });
          posts.push({
            x: x,
            z: c.z - LabStyle.VAT_AXIS + LabStyle.VAT_LAMP_OUT,
            y: LabStyle.VAT_LAMP_Y,
            tx: x,
            tz: c.z - LabStyle.VAT_AXIS + LabStyle.VAT_LAMP_AIM,
            color: LabStyle.VAT_LAMP_COLOR,
            col: v.x,
            row: v.y,
            phase: 0.0,
            flick: 1.0,
            mul: 0.0,
            noCast: true,
          });
        }
      // the clone faces the console, i.e. south and the camera
      var clone = [for (a in axis) {
        x: a.x,
        z: a.z,
        yaw: LabStyle.CLONE_YAW,
        y: LabStyle.VAT_GLASS_Y + LabStyle.CLONE_FLOAT,
      }];
      var heap = [for (a in axis) {
        x: a.x,
        z: a.z,
        yaw: LabStyle.CLONE_YAW,
        y: LabStyle.VAT_GLASS_Y,
      }];
      var spillAt = [for (v in roots) {
        x: frame[roots.indexOf(v)].x,
        z: frame[roots.indexOf(v)].z + LabStyle.SPILL_OUT,
        yaw: (FacilityModel.mix(v.x * 7349 ^ v.y * 1931) % 64) * Math.PI / 32,
      }];
      var set:LabVatSet = {
        roots: roots,
        frame: batch(scene, RenderConfig.MODELS.labVatFrame, frame, LabStyle.VAT_H, 0),
        clone: batch(scene, RenderConfig.MODELS.labClone, clone, LabStyle.CLONE_H, 0),
        slumped: batch(scene, RenderConfig.MODELS.labCloneSlumped, heap, LabStyle.CLONE_SLUMP_H, 0),
        // the medium before the glass: both are transparent, so three sorts them by distance unless
        // told, and a vat's own glass is nearer the camera than its fluid only on the front half
        fluid: batch(scene, RenderConfig.MODELS.labVatFluid, axis, LabStyle.VAT_FLUID_H, 1),
        glass: batch(scene, RenderConfig.MODELS.labVatGlass, axis, LabStyle.VAT_GLASS_H, 2),
        posts: posts,
        drain: drain,
        base: null,
        spill: spill(scene, roots.length),
        spillAt: spillAt,
      };
      return set;
    }

// one of every part at the origin, for render.lab.LabWarm: the same batches the game draws, dressed
// and patched the same, so every program key is the game's. Returns the paths to wait on
  public static function warm(scene:Scene):Array<String>
    {
      var at:Array<Models.PropPlace> = [{
        x: 0.0,
        z: 0.0,
        yaw: 0.0,
      }];
      batch(scene, RenderConfig.MODELS.labVatFrame, at, LabStyle.VAT_H, 0);
      batch(scene, RenderConfig.MODELS.labClone, at, LabStyle.CLONE_H, 0);
      batch(scene, RenderConfig.MODELS.labCloneSlumped, at, LabStyle.CLONE_SLUMP_H, 0);
      batch(scene, RenderConfig.MODELS.labVatFluid, at, LabStyle.VAT_FLUID_H, 1);
      batch(scene, RenderConfig.MODELS.labVatGlass, at, LabStyle.VAT_GLASS_H, 2);
      spill(scene, 1);
      return [
        RenderConfig.MODELS.labVatFrame,
        RenderConfig.MODELS.labClone,
        RenderConfig.MODELS.labCloneSlumped,
        RenderConfig.MODELS.labVatFluid,
        RenderConfig.MODELS.labVatGlass,
      ];
    }

// the slurry: one flat quad off lab/floor-marks' cell 8, an instance per vat, every one hidden until
// its vat starts to drain (pose). Flat at SPILL_Y over the floor, on LabDecals' cut-out material
  static function spill(scene:Scene, n:Int):InstancedMesh
    {
      if (n == 0)
        return null;
      var b = MeshBufTools.make();
      MeshBufTools.quad(b, [-0.5, 0.0, 0.5], [0.5, 0.0, 0.5], [0.5, 0.0, -0.5], [-0.5, 0.0, -0.5],
        [0.0, 0.25, 0.25, 0.25, 0.25, 0.5, 0.0, 0.5]);
      var mesh = new InstancedMesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(LabStyle.DECAL_MARKS_TEX, 'wall', 1),
        alphaTest: LabStyle.DECAL_CUT,
        side: THREE.DoubleSide,
      })), n);
      for (i in 0...n)
        mesh.setMatrixAt(i, _zero);
      mesh.name = 'lab vat spill';
      // the instances spread the whole lab; three's per-mesh cull would take the unit quad's sphere
      mesh.frustumCulled = false;
      scene.add(mesh);
      return mesh;
    }

// one batch, its material made what the part needs before the vision mask reads it
  static function batch(scene:Scene, path:String, places:Array<Models.PropPlace>, h:Float,
      order:Int):Models.InstancedProp
    {
      if (places.length > 0)
        Models.get(path, function(t)
          {
            // Dynamic: the loaded glb's mesh, which the three extern types as Object3D — its
            // geometry and Models.toLambert material are read here
            var mesh:Dynamic = Models.firstMesh(t.pivot);
            dress(path, mesh.material);
            // the clone's sway is in its own units: hand it the glb's height and foot
            if (path == RenderConfig.MODELS.labClone &&
                mesh.material.userData.labClone != true)
              {
                mesh.material.userData.labClone = true;
                mesh.geometry.computeBoundingBox();
                var bb = mesh.geometry.boundingBox;
                LabWater.patchClone(mesh.material, bb.max.y - bb.min.y, bb.min.y);
              }
          });
      var p = Models.instanced(scene, path, places, h, SOLID);
      if (places.length > 0)
        Models.get(path, function(_)
          {
            VisionMask.patchMesh(p.mesh);
            p.mesh.renderOrder = order;
            // transparent parts throw no shadow, and nothing here stands under a casting light
            p.mesh.castShadow = false;
          });
      return p;
    }

// the glass, the medium and the clone's own looks, set ONCE on the shared template material (only the
// vats draw these paths): the glass a faint double-sided tint that writes no depth, the medium a
// see-through column swirling and bubbling in its own light (LabWater.patchVat), the clone lit by it
  // Dynamic: a material off a loaded glb, which the three extern types as Dynamic on Object3D — it is
  // the loader's MeshLambertMaterial (Models.toLambert) and the fields set here are all on it
  public static function dress(path:String, mat:Dynamic):Void
    {
      if (mat.userData.labVat == true)
        return;
      mat.userData.labVat = true;
      if (path == RenderConfig.MODELS.labVatGlass)
        {
          mat.transparent = true;
          mat.opacity = LabStyle.VAT_GLASS_OPACITY;
          mat.depthWrite = false;
          mat.side = THREE.DoubleSide;
        }
      else if (path == RenderConfig.MODELS.labVatFluid)
        {
          // it WRITES depth, unlike the glass: the actor billboards draw after it (Sprites.ORD_ACTOR),
          // so without it a scientist standing behind a vat paints straight over the medium. The
          // clone is opaque and drawn first, so it still shows through
          mat.transparent = true;
          mat.opacity = LabStyle.VAT_FLUID_OPACITY;
          // both sides: the column's far wall glows BEHIND the clone, so the clone reads as the 2D
          // vat's dark figure against lit fluid (drawn back faces first, then front)
          mat.side = THREE.DoubleSide;
          mat.emissive = new Color(LabStyle.VAT_FLUID_GLOW);
          mat.emissiveIntensity = 1.0;
          LabWater.patchVat(mat);
        }
      else if (path == RenderConfig.MODELS.labClone)
        {
          // lit by the medium round it: its lamp is out in front of the glass, and unlit the clone
          // was lost in the column. Purged vats show the heap instead, so this never outlives the
          // fluid
          mat.emissive = new Color(LabStyle.CLONE_GLOW);
          mat.emissiveMap = mat.map;
          mat.emissiveIntensity = 1.0;
        }
      mat.needsUpdate = true;
    }

// ease every vat toward its flag and pose what moved; the culls
  public static function tick(set:LabVatSet, opts:Area3DTickOpts):Void
    {
      if (set.roots.length == 0 ||
          set.fluid.mesh == null ||
          set.clone.mesh == null ||
          set.slumped.mesh == null)
        return;
      if (set.base == null)
        {
          set.base = [for (p in [ set.clone, set.slumped, set.fluid ])
            [for (m in p.matrices) m.clone()]];
          for (i in 0...set.roots.length)
            pose(set, i);
        }
      var step = opts.dtMs * RenderConfig.ANIM_SPEED / (RenderConfig.BASE_MS * LabStyle.VAT_DRAIN_MULT);
      for (i in 0...set.roots.length)
        {
          var v = set.roots[i];
          var want = (v.isFlushed ? 1.0 : 0.0);
          var t = set.drain.get(v.id);
          if (t == want)
            continue;
          set.drain.set(v.id, t < want ? Math.min(want, t + step) : Math.max(want, t - step));
          pose(set, i);
        }
      for (p in [ set.frame, set.clone, set.slumped, set.fluid, set.glass ])
        Models.cull(p, opts.camera, LabStyle.VAT_CULL_R);
    }

// one vat's medium, clone and lamp from its eased drain: the level falls with an ease-in, the clone
// rides it down until its feet find the ring and gives way to the heap once the level is below its
// knees
  static function pose(set:LabVatSet, i:Int):Void
    {
      var t = set.drain.get(set.roots[i].id);
      var level = 1 - t * t * (3 - 2 * t);
      // the medium: a y scale about its own base, which is at the glb's 0
      var m = set.fluid.matrices[i].copy(set.base[2][i]);
      if (level <= 0)
        m.copy(_zero);
      else
        {
          var e = m.elements;
          e[4] *= level;
          e[5] *= level;
          e[6] *= level;
        }
      // the clone sinks once the surface reaches its crown
      var top = LabStyle.VAT_FLUID_H * level;
      var sink = Math.max(-LabStyle.CLONE_FLOAT,
        Math.min(0.0, top - LabStyle.CLONE_FLOAT - LabStyle.CLONE_H));
      var up = (top > LabStyle.CLONE_FLOAT + LabStyle.CLONE_H * LabStyle.CLONE_SLUMP_AT);
      var c = set.clone.matrices[i].copy(set.base[0][i]);
      if (up)
        c.elements[13] += sink;
      else
        c.copy(_zero);
      var h = set.slumped.matrices[i];
      if (up)
        h.copy(_zero);
      else
        h.copy(set.base[1][i]);
      set.posts[i].mul = LabStyle.VAT_LAMP_MUL * level;
      // the slurry spreads as the level falls, turned about the vertical by its hash
      var a = set.spillAt[i];
      var sc = LabStyle.SPILL_SZ * (1 - level);
      var e = _m.elements;
      _m.makeScale(1, 1, 1);
      e[0] = sc * Math.cos(a.yaw);
      e[2] = -sc * Math.sin(a.yaw);
      e[8] = sc * Math.sin(a.yaw);
      e[10] = sc * Math.cos(a.yaw);
      e[12] = a.x;
      e[13] = LabStyle.SPILL_Y;
      e[14] = a.z;
      set.spill.setMatrixAt(i, (level >= 1 ? _zero : _m));
      set.spill.instanceMatrix.needsUpdate = true;
    }

// every vat's state, for __lab()
  public static function dbg(set:LabVatSet):Array<{ root:Int, col:Int, row:Int, flushed:Bool, t:Float }>
    {
      return [for (v in set.roots) {
        root: v.id,
        col: v.x,
        row: v.y,
        flushed: v.isFlushed,
        t: set.drain.get(v.id),
      }];
    }

// drop the batches. their materials are the shared templates', so they stay
  public static function dispose(set:LabVatSet):Void
    {
      for (p in [ set.frame, set.clone, set.slumped, set.fluid, set.glass ])
        if (p.mesh != null)
          p.mesh.removeFromParent();
      if (set.spill != null)
        set.spill.removeFromParent();
    }
}
