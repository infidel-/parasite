package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Area3DTickOpts;
import render.Models;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityModel.DoorCell;
import render.facility.FacilityModel.Facility;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// one look's worth of swinging leaves. leaf k of opening c is instance 2 * c + k, and that index
// scheme is the whole bookkeeping: the per-opening arrays are indexed by c, the per-leaf ones by i
typedef DoorBatch = {
  prop:Models.InstancedProp,
  // the openings this batch draws, in instance order — the batches are grouped by LOOK, so this is
  // the only thing that maps an instance back to a cell
  cells:Array<DoorCell>,
  // the live object each opening answers to, per OPENING. null where there is none — the boot warm
  // builds this off a demo model with no area behind it, and those leaves simply stay shut
  doors:Array<objects.Door>,
  hinge:Array<Vector3>,  // per leaf: the jamb it turns about, which is also its local origin
  shut:Array<Float>,     // per leaf: its yaw when closed
  swing:Array<Float>,    // per leaf: the signed quarter turn it travels, +-PI/2
  open:Array<Float>,     // per opening: 0 shut .. 1 open, eased toward objects.Door.isOpen
};

// the facility's doors, as instanced leaves that really swing.
//
// item (b) is render-only: objects.Door already carries isOpen, frob(), the auto-close at two turns
// and the linked halves. what was missing was any geometry at all — a door cell finalises to plain
// Const.TILE_FLOOR_LINO, so before this pass the shell had a 4 x 6 unit hole in it at every doorway.
//
// NOT a glb prop, and deliberately. a door leaf is a flat slab with a rectangular panel in it, which
// is the worst possible subject for a dual-contour remesher — TRELLIS would round the edges off and
// hand back an approximation of a shape that is eight vertices exactly. so the leaf is authored here
// and the ART carries every difference between the three looks
class FacilityDoors
{
  static inline var CELL = CityConfig.CELL;
  // half a cell. a facility door opening is exactly ONE cell and a cell is 4 world units, i.e. a 2 m
  // opening, so what the generator calls a single door is a double in any real building
  static inline var LEAF_W = CELL * 0.5;

  // the three painted pairs, indexed by FacilityModel.Look
  public static final TEX:Array<String> = [
    FacilityStyle.DOOR_GLASS,
    FacilityStyle.DOOR_CABINET,
    FacilityStyle.DOOR_METAL,
  ];

  // one leaf's geometry, shared by every batch: the looks differ only in their map
  static var geo:BufferGeometry = null;

  static var _q = new Quaternion();
  static var _up = new Vector3(0, 1, 0);
  static var _one = new Vector3(1, 1, 1);

// every door in the area, one instanced batch per look. `area` may be null, which is the boot warm:
// the geometry and the programs are built the same way and nothing ever opens
  public static function build(scene:Scene, m:Facility, area:game.AreaGame):Array<DoorBatch>
    {
      var byLook = [for (_ in TEX) new Array<DoorCell>()];
      for (d in m.doors)
        byLook[d.look].push(d);
      var out = [];
      for (li in 0...TEX.length)
        if (byLook[li].length > 0)
          out.push(batch(scene, TEX[li], byLook[li], area));
      return out;
    }

// one look: its material, its instanced mesh and every leaf's turning frame
  static function batch(scene:Scene, tex:String, cells:Array<DoorCell>,
      area:game.AreaGame):DoorBatch
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var map = Textures.loadTexture(tex, 'wall', 1);
      // the art maps 0..1 across the pair and never tiles, and the edge faces sample slivers a texel
      // or two wide — repeat wrapping there would fetch from the far side of the image
      map.wrapS = map.wrapT = THREE.ClampToEdgeWrapping;
      var inst = new InstancedMesh(leafGeom(), VisionMask.patch(new MeshLambertMaterial({
        map: map,
        side: THREE.FrontSide,
      })), cells.length * 2);
      inst.castShadow = true;
      inst.receiveShadow = true;
      // tick() culls per instance, so three's own whole-mesh cull must not also have an opinion —
      // the same contract render.Models.instanced sets up for every other batch in the game
      untyped inst.frustumCulled = false;
      var b:DoorBatch = {
        prop: {
          mesh: inst,
          matrices: [],
          centres: [],
        },
        cells: cells,
        doors: [],
        hinge: [],
        shut: [],
        swing: [],
        open: [],
      };
      for (c in cells)
        {
          b.doors.push(doorAt(area, c.col, c.row));
          b.open.push(0.0);
          var cx = (c.col + 0.5) * CELL - half;
          var cz = (c.row + 0.5) * CELL - half;
          // the wall line this pair lies in, and the side it swings into
          var ux = c.alongX ? 1.0 : 0.0;
          var uz = c.alongX ? 0.0 : 1.0;
          var nx = c.alongX ? 0.0 : c.inDir * 1.0;
          var nz = c.alongX ? c.inDir * 1.0 : 0.0;
          // Ry(yaw) takes local +x to (cos yaw, 0, -sin yaw), so the yaw that points a leaf along a
          // direction is atan2(-z, x). derived rather than cased per axis: the four combinations of
          // run axis and swing side are exactly the failure a hand-written switch gets wrong once
          var yaw = Math.atan2(-uz, ux);
          // the SHORT way round to the open direction. both leaves finish pointing along it, from
          // opposite jambs, which is what a real pair does — and it falls out of taking the second
          // leaf's turn as the negative of the first
          var d0 = wrap(Math.atan2(-nz, nx) - yaw);
          for (k in 0...2)
            {
              var s = (k == 0 ? 1.0 : -1.0);
              b.hinge.push(new Vector3(cx - ux * s * LEAF_W, 0.0, cz - uz * s * LEAF_W));
              b.shut.push(k == 0 ? yaw : yaw + Math.PI);
              b.swing.push(k == 0 ? d0 : -d0);
              b.prop.matrices.push(new Matrix4());
              // the frustum centre is the SHUT centre and is never moved by the swing — see
              // FacilityStyle.DOOR_CULL_R, which is sized off how far a leaf gets from it
              b.prop.centres.push(new Vector3(cx, FacilityStyle.DOOR_H * 0.5, cz));
            }
          // pose it before the first tick, or the batch draws one frame of identity matrices with
          // every leaf stacked at the world origin
          pose(b, b.open.length - 1);
        }
      scene.add(inst);
      return b;
    }

// per-frame: ease every opening toward its live state, turn its two leaves, and cull
  public static function tick(batches:Array<DoorBatch>, opts:Area3DTickOpts):Void
    {
      var step = opts.dtMs / (RenderConfig.BASE_MS * FacilityStyle.DOOR_SWING_MULT);
      for (b in batches)
        {
          for (c in 0...b.open.length)
            {
              var want = (b.doors[c] != null && b.doors[c].isOpen ? 1.0 : 0.0);
              var t = b.open[c];
              if (t < want)
                t = (t + step > want ? want : t + step);
              else if (t > want)
                t = (t - step < want ? want : t - step);
              else continue;
              b.open[c] = t;
              pose(b, c);
            }
          Models.cull(b.prop, opts.camera, FacilityStyle.DOOR_CULL_R);
        }
    }

// write one opening's two leaf matrices from its eased state. composes in place, so nothing here
// allocates per frame
  static function pose(b:DoorBatch, c:Int):Void
    {
      for (k in 0...2)
        {
          var i = c * 2 + k;
          _q.setFromAxisAngle(_up, b.shut[i] + b.swing[i] * b.open[c]);
          b.prop.matrices[i].compose(b.hinge[i], _q, _one);
        }
    }

// tear the batches out of the scene so build() can run again. the MATERIALS are ours and are
// disposed; the geometry is the one shared static above and must not be
  public static function dispose(scene:Scene, batches:Array<DoorBatch>):Void
    {
      for (b in batches)
        {
          scene.remove(b.prop.mesh);
          b.prop.mesh.material.dispose();
        }
    }

// does this area draw this object's door as real swinging LEAVES, so the actor layer must not also
// lay its 2D icon flat on the floor under them?
//
// the actor layer's `iconOff` is otherwise only ever true for a glb prop out of
// render.world.ObjModels, and a leaf pair is not one — so every facility doorway had the old tile
// image painted across its threshold, a pale square lying under geometry that had replaced it.
// scoped to the facility on purpose: the corporate and underground-lab generators deal
// objects.Door too and nothing draws leaves for those, so there the icon is still all there is
  public static function draws(area:game.AreaGame, o:objects.AreaObject):Bool
    {
      return area != null &&
        area.typeID == AREA_FACILITY &&
        o.type == 'door';
    }

// the live door standing on a cell, or null
  static function doorAt(area:game.AreaGame, col:Int, row:Int):objects.Door
    {
      if (area == null)
        return null;
      for (o in area.getObjectsAt(col, row))
        if (o.type == 'door')
          return cast o;
      return null;
    }

// an angle folded into (-PI, PI], so a quarter turn is always taken the short way
  static inline function wrap(a:Float):Float
    {
      while (a > Math.PI)
        a -= 2 * Math.PI;
      while (a <= -Math.PI)
        a += 2 * Math.PI;
      return a;
    }

// one leaf: hinge edge at local x = 0, free edge at +LEAF_W, base at y = 0, so the instance matrix is
// a plain turn about the hinge with no recentring correction to undo
  static function leafGeom():BufferGeometry
    {
      if (geo != null)
        return geo;
      var b = MeshBufTools.make();
      var w = LEAF_W;
      var h = FacilityStyle.DOOR_H;
      var t = FacilityStyle.DOOR_T * 0.5;
      // the face the art reads off, and its back carrying the SAME u. seen from behind, local +x runs
      // the other way across the screen, so one mapping delivers the mirror of the front — and the
      // mirror of the left leaf IS the right leaf. that is why one square image serves both halves,
      // and it is exact rather than approximate: the source measures 2.0 sRGB mean absolute
      // difference about its own midline, which is film grain
      MeshBufTools.quad(b, [0, 0, t], [w, 0, t], [w, h, t], [0, h, t],
        [0, 0, 0.5, 0, 0.5, 1, 0, 1]);
      MeshBufTools.quad(b, [w, 0, -t], [0, 0, -t], [0, h, -t], [w, h, -t],
        [0.5, 0, 0, 0, 0, 1, 0.5, 1]);
      // the hinge edge, the free edge and the top, each sampling a sliver of the art's own frame
      // rather than a flat colour. they exist because this camera looks down at 51 degrees, where a
      // bare quad would vanish edge-on the moment the leaf swung square to the view
      MeshBufTools.quad(b, [0, 0, -t], [0, 0, t], [0, h, t], [0, h, -t],
        [0.005, 0, 0.02, 0, 0.02, 1, 0.005, 1]);
      MeshBufTools.quad(b, [w, 0, t], [w, 0, -t], [w, h, -t], [w, h, t],
        [0.48, 0, 0.495, 0, 0.495, 1, 0.48, 1]);
      MeshBufTools.quad(b, [0, h, t], [w, h, t], [w, h, -t], [0, h, -t],
        [0, 0.985, 0.5, 0.985, 0.5, 1, 0, 1]);
      // no underside: it stands on the floor and is never seen, and this is per leaf
      geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      return geo;
    }
}
