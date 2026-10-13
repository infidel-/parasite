package render.lab;

import three.Three;
import citygen.CityConfig;
import render.Area3DTickOpts;
import render.Models;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityStyle;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// one look's sliding leaves: the instanced mesh and, per OPENING, the live door, its two leaves'
// shut frames and its eased state
typedef LabDoorBatch = {
  prop:Models.InstancedProp,
  // per opening: the live door whose state the pair follows (null in the warm)
  doors:Array<objects.Door>,
  // per opening: the eased open fraction, 0 shut to 1 fully slid away
  open:Array<Float>,
  // per LEAF: where its outer stile stands shut, its yaw, and its full slide
  base:Array<Vector3>,
  yaw:Array<Float>,
  slide:Array<Vector3>,
  // per opening, for __lab(): its first cell and its axis
  cells:Array<{ col:Int, row:Int, alongX:Bool }>,
};

// the lab's doorways: TWO cells wide, closed by two heavy leaves a CELL wide each that slide apart
// into the masonry either side. not render.facility.FacilityDoors, whose pair is two LEAF_W leaves
// to a ONE-cell opening: four of those in a lab doorway would put two leaves sliding into the
// opposite cell's opening and standing in it when open.
//
// the art is one leaf per image (LabStyle.DOOR_*), mapped 0..1 over the leaf's face — the left edge
// the stile that slides into the wall, the right edge the one that meets its twin. The twin is the
// same leaf turned half round, so its back face, which carries the same u, reads as the mirror: one
// image serves both, exactly as a facility door image serves its pair
class LabDoors
{
  static inline var CELL = CityConfig.CELL;
  static var geo:BufferGeometry = null;
  static var _q = new Quaternion();
  static var _p = new Vector3();
  static var _up = new Vector3(0, 1, 0);
  static var _one = new Vector3(1, 1, 1);

// every opening in the model, one instanced batch per look. `area` null is the warm: built the same
// way, nothing opens
  public static function build(scene:Scene, m:Facility, area:game.AreaGame):Array<LabDoorBatch>
    {
      var looks = [LabStyle.DOOR_BLAST, LabStyle.DOOR_SERVICE, LabStyle.DOOR_RESEARCH,
        LabStyle.DOOR_VAT];
      var by = [for (_ in looks) []];
      for (d in m.doors)
        {
          // an opening is listed once, off its first cell: the second has its twin before it
          var dc = d.alongX ? 1 : 0;
          var dr = d.alongX ? 0 : 1;
          if (render.facility.FacilityModel.isDoor(m, d.col - dc, d.row - dr))
            continue;
          by[lookOf(m, d.col, d.row, d.alongX)].push(d);
        }
      var out = [];
      for (i in 0...looks.length)
        if (by[i].length > 0)
          out.push(batch(scene, looks[i], by[i], area));
      return out;
    }

// which leaf an opening takes, off the rooms either side of it: the vat chamber's containment
// door, the lift lobby's blast door, the research wing's glazed one, and a plain service leaf
// anywhere else
  static function lookOf(m:Facility, col:Int, row:Int, alongX:Bool):Int
    {
      var dc = alongX ? 0 : 1;
      var dr = alongX ? 1 : 0;
      var look = 1;
      for (s in [-1, 1])
        {
          var c = col + dc * s;
          var r = row + dr * s;
          if (!render.facility.FacilityModel.inside(m, c, r))
            continue;
          var sf = m.surf[r][c];
          if (sf == Surf.LAB_VAT ||
              sf == Surf.LAB_PAD)
            return 3;
          if (sf == Surf.LAB_ENTRANCE)
            look = 0;
          else if (sf == Surf.LAB_RESEARCH &&
              look != 0)
            look = 2;
        }
      return look;
    }

// one look: its material, its mesh and every leaf's frame
  static function batch(scene:Scene, tex:String, cells:Array<render.facility.FacilityModel.DoorCell>,
      area:game.AreaGame):LabDoorBatch
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var map = Textures.loadTexture(tex, 'wall', 1);
      // 0..1 over the leaf and never tiled: the edge faces sample slivers at the image's rim, which
      // repeat wrapping would fetch from the far side
      map.wrapS = map.wrapT = THREE.ClampToEdgeWrapping;
      var inst = new InstancedMesh(leafGeom(), VisionMask.patch(new MeshLambertMaterial({
        map: map,
        side: THREE.FrontSide,
      })), cells.length * 2);
      inst.name = 'lab door ' + tex;
      inst.castShadow = true;
      inst.receiveShadow = true;
      untyped inst.frustumCulled = false;
      var b:LabDoorBatch = {
        prop: {
          mesh: inst,
          matrices: [],
          centres: [],
        },
        doors: [],
        open: [],
        base: [],
        yaw: [],
        slide: [],
        cells: [],
      };
      for (c in cells)
        {
          b.doors.push(doorAt(area, c.col, c.row));
          b.open.push(0.0);
          b.cells.push({
            col: c.col,
            row: c.row,
            alongX: c.alongX,
          });
          // the opening's centre is the boundary between its two cells
          var ux = c.alongX ? 1.0 : 0.0;
          var uz = c.alongX ? 0.0 : 1.0;
          var cx = (c.col + 0.5 + ux * 0.5) * CELL - half;
          var cz = (c.row + 0.5 + uz * 0.5) * CELL - half;
          // Ry(yaw) takes local +x to (cos yaw, 0, -sin yaw), so atan2(-z, x) points it along u
          var yaw = Math.atan2(-uz, ux);
          var run = CELL + LabStyle.DOOR_CLEAR;
          for (k in 0...2)
            {
              var s = (k == 0 ? 1.0 : -1.0);
              // the leaf's local x runs from its outer stile (0) to its meeting stile (CELL): leaf 0
              // stands on the low side of the centre facing +u, its twin on the high side turned
              // round, and each slides out the way its outer stile faces
              b.base.push(new Vector3(cx - ux * s * CELL, 0.0, cz - uz * s * CELL));
              b.yaw.push(k == 0 ? yaw : yaw + Math.PI);
              b.slide.push(new Vector3(-s * ux * run, 0.0, -s * uz * run));
              b.prop.matrices.push(new Matrix4());
              b.prop.centres.push(new Vector3(cx, FacilityStyle.DOOR_H * 0.5, cz));
            }
          pose(b, b.open.length - 1);
        }
      scene.add(inst);
      return b;
    }

// per-frame: ease every opening toward its door's live state, pose what moved, and cull
  public static function tick(batches:Array<LabDoorBatch>, opts:Area3DTickOpts):Void
    {
      var step = opts.dtMs * RenderConfig.ANIM_SPEED / (RenderConfig.BASE_MS * LabStyle.DOOR_MULT);
      for (b in batches)
        {
          for (c in 0...b.open.length)
            {
              var want = (b.doors[c] != null && b.doors[c].isOpen ? 1.0 : 0.0);
              var t = b.open[c];
              if (t == want)
                continue;
              b.open[c] = (t < want ? Math.min(want, t + step) : Math.max(want, t - step));
              pose(b, c);
            }
          Models.cull(b.prop, opts.camera, LabStyle.DOOR_CULL_R, null, false);
        }
    }

// write one opening's two leaf matrices from its eased state, eased in and out so the slab
// starts and stops like something heavy
  static function pose(b:LabDoorBatch, c:Int):Void
    {
      var t = b.open[c];
      var e = t * t * (3 - 2 * t);
      for (k in 0...2)
        {
          var i = c * 2 + k;
          _q.setFromAxisAngle(_up, b.yaw[i]);
          _p.set(b.base[i].x + b.slide[i].x * e, 0.0, b.base[i].z + b.slide[i].z * e);
          b.prop.matrices[i].compose(_p, _q, _one);
        }
    }

// tear the batches out so build() can run again; the geometry is shared and stays
  public static function dispose(batches:Array<LabDoorBatch>):Void
    {
      for (b in batches)
        {
          b.prop.mesh.removeFromParent();
          b.prop.mesh.material.dispose();
        }
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

// one leaf: CELL wide, DOOR_H tall, DOOR_T thick, its local x from the outer stile to the meeting
// one. the face and its back carry the same u, so the back reads as the mirror (see the header);
// the stiles and the top sample slivers of the art's own rim, so a leaf seen edge-on is still steel
  static function leafGeom():BufferGeometry
    {
      if (geo != null)
        return geo;
      var b = MeshBufTools.make();
      var w = CELL;
      var h = FacilityStyle.DOOR_H;
      // the skirt down to the dropped kerb, sampling the leaf's own bottom row (ClampToEdge)
      var y0 = -FacilityStyle.KERB_DROP;
      var v0 = y0 / h;
      var t = LabStyle.DOOR_T * 0.5;
      MeshBufTools.quad(b, [0, y0, t], [w, y0, t], [w, h, t], [0, h, t],
        [0, v0, 1, v0, 1, 1, 0, 1]);
      MeshBufTools.quad(b, [w, y0, -t], [0, y0, -t], [0, h, -t], [w, h, -t],
        [1, v0, 0, v0, 0, 1, 1, 1]);
      MeshBufTools.quad(b, [0, y0, -t], [0, y0, t], [0, h, t], [0, h, -t],
        [0.01, v0, 0.03, v0, 0.03, 1, 0.01, 1]);
      MeshBufTools.quad(b, [w, y0, t], [w, y0, -t], [w, h, -t], [w, h, t],
        [0.97, v0, 0.99, v0, 0.99, 1, 0.97, 1]);
      MeshBufTools.quad(b, [0, h, t], [w, h, t], [w, h, -t], [0, h, -t],
        [0, 0.985, 1, 0.985, 1, 1, 0, 1]);
      geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      return geo;
    }
}
