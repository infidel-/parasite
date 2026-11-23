package render.library;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// what LibraryWall hung, for the build's trace
typedef LibraryWallSet = {
  art:Int,     // framed pictures, the notice board, the clock and the plaques
  posters:Int, // the propaganda posters, on walls and on the stack ranks' ends
};

// the library's WALLS: framed pictures and plaques off library/wall-art (a PACK16, each cell filled to
// its box and sized here by its own aspect) and the propaganda posters off library/posters (4 x 2),
// as quads, one mesh per sheet — render.lab.LabWall's reading of the surface-vs-silhouette guard.
//
// A WALL CELL WITH BARE FLOOR IN FRONT, on the north, west and east walls only (a south wall's face
// looks away from the camera): a hole in a bookcase run, the lobby's and the stacks' walls, the
// corridor's. A lone cell (a bookcase hole) hangs one thing on WALL_PCT; a longer bare run one per
// WALL_SPACING cells. What hangs is the room's: each role deals off its own lists.
//
// AND THE STACK RANKS' SOUTH ENDS, where the rank stands free of the wall: a poster on RANK_PCT of them.
// Every pick is off the cell hash (FacilityModel.mix); nothing is saved
class LibraryWall
{
  static inline var CELL = CityConfig.CELL;
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // how far off the masonry a quad hangs
  static inline var PROUD = 0.02;
  // a lone bare cell takes something this often, a longer run one per this many cells
  static inline var WALL_PCT = 75;
  static inline var WALL_SPACING = 3;
  // of what hangs, a poster this often (else a picture)
  static inline var POSTER_PCT = 35;
  // a free rank end takes a poster this often, this tall, centred this high
  static inline var RANK_PCT = 55;
  static inline var POSTER_H = 2.8;
  static inline var POSTER_Y = 3.0;
  static inline var RANK_POSTER_H = 2.6;
  static inline var RANK_POSTER_Y = 2.55;

  // the art sheet's cells' width:height, measured off the drop (tools/pack16.py --fill), each one's
  // longest edge on the wall, and its centre's height
  static var ART_ASPECT = [0.6830, 0.7402, 0.7455, 0.8050, 1.3129, 1.3718, 1.4503, 1.0000, 0.7317,
    0.7220, 1.3235, 0.9793, 1.3086, 0.8309, 1.5984, 1.3036];
  static var ART_MAX = [2.4, 2.4, 2.5, 2.2, 2.7, 2.6, 2.6, 2.0, 2.0, 2.0, 2.8, 1.3, 1.8, 1.6, 1.2, 2.2];
  static var ART_Y = [3.2, 3.2, 3.2, 3.2, 3.2, 3.2, 3.2, 3.2, 3.2, 3.2, 2.9, 4.0, 3.0, 3.4, 2.5, 3.1];
  // and the posters' (tools/pack16.py --cols 4 --rows 2 --cellh 512 --fill)
  static var POSTER_ASPECT = [0.4556, 0.4647, 0.4692, 0.4624, 0.4601, 0.4703, 0.4726, 0.4726];

  // per room role (corridor, hall, lobby, stacks, archive): the pictures and the posters each deals.
  // art: 0-3 portraits (dean, professor, founder, scholar), 4 the main building, 5 the sea, 6 a map,
  // 7 a star chart, 8 a skull, 9 a root, 10 the notice board, 11 the clock, 12 a diploma, 13 the crest,
  // 14 a brass plaque, 15 a graduation photograph. posters: 0 SILENCE, 1 OBEDIENCE, 2 THE ARCHIVE,
  // 3 ASCEND, 4 RETURN, 5 READS YOU, 6 FACULTY ONLY, 7 DISCIPLINE
  static var ART = [
    [ 10, 11, 15, 12, 4, 5 ],
    [ 0, 1, 2, 3, 4, 5, 6, 9, 15 ],
    [ 10, 11, 12, 13, 14, 15, 0, 4 ],
    [ 6, 7, 4, 5, 8 ],
    [ 2, 6, 7, 8, 9, 3 ],
  ];
  static var POSTERS = [
    [ 0, 3, 5, 7, 4 ],
    [ 0, 1, 3, 5, 7 ],
    [ 0, 1, 4, 7 ],
    [ 1, 3, 5, 2, 4 ],
    [ 2, 6 ],
  ];

// everything on the walls and the rank ends. `tile` is the area's cell type
  public static function build(scene:Scene, m:Facility, tile:(Int, Int)->Int):LibraryWallSet
    {
      var art = MeshBufTools.make();
      var posters = MeshBufTools.make();
      var n = [0, 0];
      var seen = new Map<Int, Bool>();
      for (dir in [ 0, 2, 3 ])
        {
          // a run follows the WALL: along x for a wall in z, along z for one in x
          var sc = (dir < 2 ? 1 : 0);
          var sr = (dir < 2 ? 0 : 1);
          for (row in 0...m.h)
            for (col in 0...m.w)
              {
                var k = (dir * m.h + row) * m.w + col;
                if (seen.exists(k) ||
                    !hangs(m, tile, col, row, dir))
                  continue;
                var len = 0;
                while (hangs(m, tile, col + sc * len, row + sr * len, dir))
                  {
                    seen.set((dir * m.h + row + sr * len) * m.w + col + sc * len, true);
                    len++;
                  }
                var h = FacilityModel.mix((col * 668265263) ^ (row * 1103515245) ^ (dir * 374761393));
                var role = roleOf(m.surf[row][col]);
                // a lone cell on WALL_PCT, a run every WALL_SPACING from a hashed start
                var at = [];
                if (len == 1)
                  {
                    if ((h >>> 3) % 100 < WALL_PCT)
                      at.push(0);
                  }
                else
                  {
                    var d = (h >>> 3) % Std.int(Math.min(WALL_SPACING, len));
                    while (d < len)
                      {
                        at.push(d);
                        d += WALL_SPACING;
                      }
                  }
                for (i in 0...at.length)
                  {
                    var r = FacilityModel.mix(h + i * 7919);
                    var c = col + sc * at[i];
                    var rw = row + sr * at[i];
                    if ((r >>> 5) % 100 < POSTER_PCT)
                      {
                        var l = POSTERS[role];
                        var p = l[(r >>> 9) % l.length];
                        hang(posters, m, c, rw, dir, POSTER_Y, POSTER_H * POSTER_ASPECT[p], POSTER_H,
                          cellOf(p, 4, 2));
                        n[1]++;
                        continue;
                      }
                    var l = ART[role];
                    var a = l[(r >>> 9) % l.length];
                    var asp = ART_ASPECT[a];
                    var w = (asp >= 1 ? ART_MAX[a] : ART_MAX[a] * asp);
                    hang(art, m, c, rw, dir, ART_Y[a], w, w / asp, cellOf(a, 4, 4));
                    n[0]++;
                  }
              }
        }
      // and the free south end of every stack rank
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (tile(col, row) != Const.TILE_LIB_STACK ||
                !LibraryStyle.isFloor(tile(col, row + 1)))
              continue;
            var h = FacilityModel.mix((col * 73856093) ^ (row * 19349663) ^ 0x2f1);
            if ((h >>> 3) % 100 >= RANK_PCT)
              continue;
            var l = POSTERS[roleOf(m.surf[row][col])];
            var p = l[(h >>> 9) % l.length];
            var c = CityConfig.cellToWorld(col, row);
            var z = c.z + LibraryStyle.STACK_W / 2 + PROUD;
            var hw = RANK_POSTER_H * POSTER_ASPECT[p] / 2;
            pane(posters, c.x - hw, c.x + hw, z, z, 1, RANK_POSTER_Y - RANK_POSTER_H / 2,
              RANK_POSTER_Y + RANK_POSTER_H / 2, cellOf(p, 4, 2));
            n[1]++;
          }
      add(scene, art, LibraryStyle.WALL_ART);
      add(scene, posters, LibraryStyle.POSTERS);
      return {
        art: n[0],
        posters: n[1],
      };
    }

// one quad off each sheet at the origin, for LibraryArea.warm
  public static function warm(scene:Scene):Void
    {
      for (s in [ LibraryStyle.WALL_ART, LibraryStyle.POSTERS ])
        {
          var b = MeshBufTools.make();
          pane(b, -1.0, 1.0, 0.0, 0.0, 1, 1.0, 3.0, cellOf(0, 4, 4));
          add(scene, b, s);
        }
    }

// can something hang on the `dir` wall of this cell: bare library floor looking at plain masonry whose
// wall line carries on past it both ways (LabWall.hangs' rule: a quad centred on a cell where the line
// stops would overhang the wall's end)
  static function hangs(m:Facility, tile:(Int, Int)->Int, col:Int, row:Int, dir:Int):Bool
    {
      if (!FacilityModel.inside(m, col, row) ||
          !LibraryStyle.isFloor(tile(col, row)))
        return false;
      var c = col + DC[dir];
      var r = row + DR[dir];
      if (!FacilityModel.isSolidWall(m, c, r))
        return false;
      var sc = (dir < 2 ? 1 : 0);
      var sr = (dir < 2 ? 0 : 1);
      return FacilityGeom.carries(m, c - sc, r - sr) &&
        FacilityGeom.carries(m, c + sc, r + sr);
    }

// the room role a cell's surface names, as ART's row
  static function roleOf(s:Surf):Int
    {
      return switch (s)
        {
          case Surf.LIB_HALL: 1;
          case Surf.LIB_LOBBY: 2;
          case Surf.LIB_STACKS: 3;
          case Surf.LIB_ARCHIVE: 4;
          default: 0;
        }
    }

// cell `i` of a cols x rows sheet as [u0, u1, v0, v1], v flipped to reading order
  static function cellOf(i:Int, cols:Int, rows:Int):Array<Float>
    {
      var c = i % cols;
      var r = Std.int(i / cols);
      return [c / cols, (c + 1) / cols, 1 - (r + 1) / rows, 1 - r / rows];
    }

// one quad `w` wide and `h` tall centred `y` up the masonry beside (col, row), PROUD off the slab's face
  static function hang(b:MeshBuf, m:Facility, col:Int, row:Int, dir:Int, y:Float, w:Float, h:Float,
      uv:Array<Float>):Void
    {
      var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
      var c = CityConfig.cellToWorld(col, row);
      // the face looks BACK at the cell it is read from, the opposite of the side the masonry is on
      var d = dir ^ 1;
      if (d < 2)
        {
          var z = (d == 0 ? s.z0 - PROUD : s.z1 + PROUD);
          pane(b, c.x - w / 2, c.x + w / 2, z, z, d, y - h / 2, y + h / 2, uv);
          return;
        }
      var x = (d == 2 ? s.x0 - PROUD : s.x1 + PROUD);
      pane(b, x, x, c.z - w / 2, c.z + w / 2, d, y - h / 2, y + h / 2, uv);
    }

// one upright quad facing `dir` wearing the sheet rect `uv`
  static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int, y0:Float, y1:Float,
      uv:Array<Float>):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      MeshBufTools.quad(b,
        [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [uv[0], uv[2], uv[1], uv[2], uv[1], uv[3], uv[0], uv[3]]);
    }

// one sheet's quads as one mesh: alphaTest for the cut-out art (opaque, so it writes depth and the
// vision mask keeps its darkening branch), the posters plain
  static function add(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        alphaTest: (tex == LibraryStyle.WALL_ART ? LibraryStyle.DECAL_CUT : 0.0),
      });
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(mat));
      mesh.name = 'library wall ' + tex;
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
