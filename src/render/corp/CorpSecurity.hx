package render.corp;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.Textures;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the security room's own kit, and the tower's CCTV cameras that feed it.
//
// THE VIDEO WALL is one panel of corp/cctv-wall per console cell, hung on the north wall the console
// stands against (gen.corp.CorpRooms.security puts it there because it is the wall this camera looks
// at). Its own material, because the feeds GLOW: the art is its own emissive map, and the bezels are
// near black so only the screens clear the bloom. THE CAMERAS stand on the corridor's inside corners
// and the reception's, one corner in CAM_EVERY, each a wall-mounted glb with a red recording light in
// render.corp.CorpFurniture's blinking LED mesh. Both are pure functions of the grid, so the prop
// batch and the LED pass find the same cameras without either having run first
class CorpSecurity
{
// the console cells that hang a panel: a worktop on a security room's first row, with masonry behind
  public static function videoCells(m:Facility):Array<{ col:Int, row:Int }>
    {
      var out = [];
      for (r in m.rooms)
        {
          if (r.role != gen.corp.CorpTemp.ROLE_SECURITY)
            continue;
          for (col in r.x1...r.x2 + 1)
            if (FacilityModel.inside(m, col, r.y1) &&
                m.table[r.y1][col] &&
                FacilityModel.isSolidWall(m, col, r.y1 - 1))
              out.push({
                col: col,
                row: r.y1,
              });
        }
      return out;
    }

// and those cells as the stretch of wall render.corp.CorpSigns keeps its framed art off, with the
// hand the wall is on (north)
  public static function videoClear(m:Facility):Array<{ col:Int, row:Int, dir:Int }>
    {
      return [for (c in videoCells(m)) {
        col: c.col,
        row: c.row,
        dir: 0,
      }];
    }

// hang the video wall; answers how many panels
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var cells = videoCells(m);
      for (c in cells)
        {
          var s = FacilityGeom.slab(m, c.col, c.row - 1);
          var w = CityConfig.cellToWorld(c.col, c.row);
          var z = s.z1 + CorpStyle.VIDEO_PROUD;
          FacilityGeom.pane(b, w.x - CorpStyle.VIDEO_W / 2, w.x + CorpStyle.VIDEO_W / 2, z, z, 1,
            CorpStyle.VIDEO_Y0, CorpStyle.VIDEO_Y0 + CorpStyle.VIDEO_H);
        }
      addScreens(scene, b);
      return cells.length;
    }

// the video wall's material: its art is its own emissive map. Public for render.corp.CorpWarm, which
// has no security room to hang one in
  public static function addScreens(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var tex = Textures.loadTexture(CorpStyle.CCTV_WALL, 'wall', 1);
      var mat = VisionMask.patch(new MeshLambertMaterial({
        map: tex,
        emissiveMap: tex,
        emissive: new Color(0xffffff),
        emissiveIntensity: CorpStyle.VIDEO_EMISSIVE,
        side: THREE.FrontSide,
      }));
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.name = 'corp video wall';
      mesh.receiveShadow = false;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// every CCTV camera on the plate, as the placement of its glb: on the NORTH wall of an inside corner
// (the wall this camera looks at, so the lens is seen), CAM_SIDE out from the side wall and turned
// CAM_TURN toward the floor it watches. A corridor cell (no room owns it) or a reception cell, with
// nothing standing on it
  public static function cams(m:Facility):Array<Models.PropPlace>
    {
      var out:Array<Models.PropPlace> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!FacilityModel.inside(m, col, row) ||
                m.table[row][col] ||
                m.fit[row][col] != 0 ||
                !FacilityModel.isSolidWall(m, col, row - 1))
              continue;
            var s = m.surf[row][col];
            if (s != Surf.RECEPTION &&
                (s != Surf.CARPET ||
                roomAt(m, col, row)))
              continue;
            for (side in [2, 3])
              {
                var sc = col + FacilityGeom.DC[side];
                if (!FacilityModel.isSolidWall(m, sc, row) ||
                    FacilityModel.mix((col * 73856093) ^ (row * 19349663) ^ side) %
                    CorpStyle.CAM_EVERY != 0)
                  continue;
                var ss = FacilityGeom.slab(m, sc, row);
                var yaw = (side == 2 ? CorpStyle.CAM_TURN : -CorpStyle.CAM_TURN);
                var x = (side == 2 ? ss.x1 + CorpStyle.CAM_SIDE : ss.x0 - CorpStyle.CAM_SIDE);
                var z = FacilityGeom.slab(m, col, row - 1).z1;
                // the glb is recentred on its footprint, so its centre is half its depth out along
                // the way it faces from the plate
                out.push({
                  x: x + Math.sin(yaw) * CorpStyle.CAM_D / 2,
                  z: z + Math.cos(yaw) * CorpStyle.CAM_D / 2,
                  yaw: yaw,
                  y: CorpStyle.CAM_Y,
                });
              }
          }
      return out;
    }

// each camera's red recording light, one speck on its wall plate beside the arm, into the blinking
// LED buffer (render.facility.FacilityDeco.blink's mode 8)
  public static function camLeds(m:Facility, b:MeshBuf):Void
    {
      var sz = CorpStyle.CAM_LED_SIZE / 2;
      for (c in cams(m))
        {
          // the plate's own frame: across it, and out of the wall
          var rx = Math.cos(c.yaw);
          var rz = -Math.sin(c.yaw);
          var fx = Math.sin(c.yaw);
          var fz = Math.cos(c.yaw);
          var back = CorpStyle.CAM_D / 2 - CorpStyle.CAM_LED[2];
          var px = c.x - fx * back + rx * CorpStyle.CAM_LED[0];
          var pz = c.z - fz * back + rz * CorpStyle.CAM_LED[0];
          var py = c.y + CorpStyle.CAM_LED[1];
          var hash = FacilityModel.mix(Std.int(px * 131) ^ Std.int(pz * 977));
          var ph = ((hash >>> 1) % 1000) / 1000;
          MeshBufTools.quadRGB(b,
            [px - rx * sz, py - sz, pz - rz * sz],
            [px + rx * sz, py - sz, pz + rz * sz],
            [px + rx * sz, py + sz, pz + rz * sz],
            [px - rx * sz, py + sz, pz - rz * sz],
            [0, 0, 1, 0, 1, 1, 0, 1], 1.0, ph, 8.0);
        }
    }

// is this cell inside one of the plate's rooms?
  static function roomAt(m:Facility, col:Int, row:Int):Bool
    {
      for (r in m.rooms)
        if (col >= r.x1 &&
            col <= r.x2 &&
            row >= r.y1 &&
            row <= r.y2)
          return true;
      return false;
    }
}
