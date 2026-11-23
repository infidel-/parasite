package render.library;

import three.Three;
import render.Models.PropPlace;
import render.Textures;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the BOOKS on every shelf: one quad per opening between a bookcase's boards, and on both faces of a
// stack rank, each wearing its own band of library/shelf-books (sixteen shelf rows, one per 128-px band
// of a 1024 x 2048 sheet) at a hashed window and mirror, so no two cases read alike. The bookcase and
// stack glbs' fronts are bare wood behind them (models-src/library/library_build.py). One mesh for the
// whole floor; nothing is saved, every pick is off the placement's own position
class LibraryBooks
{
  static inline var BANDS = 16;
  // a band's texels, width over height
  static inline var BAND_ASPECT = 8.0;
  // half a texel of the sheet's height, kept off each band's edge so a mip never reads the next row
  static inline var BAND_PAD = 0.5 / 2048;

// every shelf of every bookcase and stack rank, off the furniture plan's own placements. Returns the
// quads laid
  public static function build(scene:Scene, cases:Array<PropPlace>, stacks:Array<PropPlace>):Int
    {
      var b = MeshBufTools.make();
      var n = 0;
      for (p in cases)
        n += face(b, p, LibraryStyle.CASE_W, LibraryStyle.CASE_FRONT);
      for (p in stacks)
        for (s in [ 1, -1 ])
          n += face(b, p, LibraryStyle.STACK_W, s * LibraryStyle.STACK_D / 2);
      add(scene, b);
      return n;
    }

// one quad off the sheet at the origin, for LibraryArea.warm
  public static function warm(scene:Scene):Void
    {
      var b = MeshBufTools.make();
      face(b, {
        x: 0.0,
        z: 0.0,
        yaw: 0.0,
      }, LibraryStyle.CASE_W, LibraryStyle.CASE_FRONT);
      add(scene, b);
    }

// the shelves of one face `w` wide, `front` along the piece's own +z off its centre (negative for a
// stack's back face), turned with the piece
  static function face(b:MeshBuf, p:PropPlace, w:Float, front:Float):Int
    {
      var cs = Math.cos(p.yaw);
      var sn = Math.sin(p.yaw);
      var lz = front + (front > 0 ? 1 : -1) * LibraryStyle.BOOKS_PROUD;
      var hw = w / 2 - LibraryStyle.SHELF_INSET;
      var seed = FacilityModel.mix(Std.int(p.x * 131) ^ (Std.int(p.z * 977) << 9) ^ (front > 0 ? 0 : 0x55));
      var sh = LibraryStyle.SHELVES;
      var n = Std.int(sh.length / 2);
      for (k in 0...n)
        {
          var h = FacilityModel.mix(seed + k * 7919);
          var y0 = sh[2 * k];
          var y1 = sh[2 * k + 1];
          // the band, and a window across it as wide as the opening's own aspect, mirrored half the time
          var band = (h >>> 3) % BANDS;
          var uw = Math.min(1.0, (2 * hw / (y1 - y0)) / BAND_ASPECT);
          var u0 = ((h >>> 8) % 1001) / 1000 * (1 - uw);
          var u1 = u0 + uw;
          if ((h >>> 20) % 2 == 1)
            {
              var t = u0;
              u0 = u1;
              u1 = t;
            }
          var v1 = 1 - band / BANDS - BAND_PAD;
          var v0 = 1 - (band + 1) / BANDS + BAND_PAD;
          // the piece's local x across its face, read left to right from in front of that face
          var lx0 = (front > 0 ? -hw : hw);
          var lx1 = -lx0;
          var ax = p.x + lx0 * cs + lz * sn;
          var az = p.z - lx0 * sn + lz * cs;
          var bx = p.x + lx1 * cs + lz * sn;
          var bz = p.z - lx1 * sn + lz * cs;
          MeshBufTools.quad(b,
            [ax, y0, az], [bx, y0, bz], [bx, y1, bz], [ax, y1, az],
            [u0, v0, u1, v0, u1, v1, u0, v1]);
        }
      return n;
    }

// the floor's books as one mesh, under the pendants and shaded by the vision sweep
  static function add(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = new MeshLambertMaterial({
        map: Textures.loadTexture(LibraryStyle.SHELF_BOOKS, 'wall', 1),
        side: THREE.DoubleSide,
      });
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(mat));
      mesh.name = 'library books';
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
