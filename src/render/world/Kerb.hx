package render.world;

import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// one kerb segment: the INNER edge a->b, lying on the raised surface's own boundary, plus the unit
// normal pointing at the lower surface beside it
typedef KerbSeg = {
  ax:Float,
  az:Float,
  bx:Float,
  bz:Float,
  nx:Float,
  nz:Float,
};

// the kerb-edging strip: a band `bw` wide protruding off a raised surface over the lower one, plus
// the vertical face that drops from it. shared by render.world.Ground (a city walkway, raised
// RenderConfig.CURB_H over the road) and render.facility.FacilityGround (a compound's pavement,
// which instead has the road and the park dropped under it) — the two differ only in which of the
// pair moved, so the two heights are arguments and nothing else is.
//
// the whole reason this is collect-then-emit rather than a quad per edge is the MITER: at a shared
// boundary vertex the two segments' outer edges meet at the intersection of their offset lines, so
// they abut exactly. emitted per edge instead they leave a gap at every convex corner and OVERLAP
// at every concave one — and two coplanar bands at one y z-fight
class Kerb
{
// collect one segment, its outward side given as any point on the lower surface. a zero-length
// segment is dropped: it carries no normal and would poison the miter at its own vertex
  public static function push(list:Array<KerbSeg>, ax:Float, az:Float, bx:Float, bz:Float,
      tx:Float, tz:Float):Void
    {
      if ((bx - ax) * (bx - ax) + (bz - az) * (bz - az) < 1e-9)
        return;
      // perpendicular to a->b, flipped to point toward (tx,tz)
      var nx = bz - az;
      var nz = -(bx - ax);
      if (nx * (tx - ax) + nz * (tz - az) < 0)
        {
          nx = -nx;
          nz = -nz;
        }
      var nl = Math.sqrt(nx * nx + nz * nz);
      nx /= nl;
      nz /= nl;
      // and WIND a->b so the band `emit` lays over it comes out facing UP. the emitter walks
      // a, a+n, b+n, b, which MeshBufTools.quad reads as counter-clockwise only when a->b turns
      // onto the outward normal the positive way — and two of the four cell edges a caller hands
      // over arrive the other way round. the whole segment goes with it, top band and drop face
      // together, so under a FrontSide material a kerb was drawn on a surface's +z and -x sides
      // and simply missing from its -z and +x ones, leaving the drop's own height as a slit
      // looking under the slab
      if ((bx - ax) * nz - (bz - az) * nx < 0)
        {
          var t = ax;
          ax = bx;
          bx = t;
          t = az;
          az = bz;
          bz = t;
        }
      list.push({
        ax: ax,
        az: az,
        bx: bx,
        bz: bz,
        nx: nx,
        nz: nz,
      });
    }

// emit every collected segment into `b`: the top band at `yTop` and the face dropping from it to
// `yBot`. `bw` is how far the band protrudes over the lower surface, `bt` the world units per
// texture repeat along the run
  public static function emit(b:MeshBuf, list:Array<KerbSeg>, bw:Float, bt:Float,
      yTop:Float, yBot:Float):Void
    {
      // every segment end that lands on a given boundary vertex, so a join can find its partner.
      // quantized, because two segments meeting at a corner arrive at it by different arithmetic
      inline function vkey(x:Float, z:Float):String
        return Std.string(Math.round(x * 16)) + '_' + Std.string(Math.round(z * 16));
      var vmap = new Map<String, Array<{ s:Int, e:Int }>>();
      for (i in 0...list.length)
        for (e in 0...2)
          {
            var c = list[i];
            var k = vkey(e == 0 ? c.ax : c.bx, e == 0 ? c.az : c.bz);
            var at = vmap.get(k);
            if (at == null)
              {
                at = [];
                vmap.set(k, at);
              }
            at.push({
              s: i,
              e: e,
            });
          }
      // where segment `i`'s end `e` puts its OUTER corner: the miter point V + bw*(n1+n2)/(1+n1.n2),
      // i.e. where the two offset lines cross. a dangling end, or a junction of more than two, takes
      // a square end instead — and so does a near-reversal, where the miter point runs to infinity
      function outer(i:Int, e:Int):{ x:Float, z:Float }
        {
          var c = list[i];
          var vx = (e == 0 ? c.ax : c.bx);
          var vz = (e == 0 ? c.az : c.bz);
          var others = vmap.get(vkey(vx, vz));
          var oj = -1;
          var cnt = 0;
          for (it in others)
            if (it.s != i ||
                it.e != e)
              {
                oj = it.s;
                cnt++;
              }
          if (cnt == 1)
            {
              var nj = list[oj];
              var denom = 1 + c.nx * nj.nx + c.nz * nj.nz;
              if (denom > 0.25)
                return {
                  x: vx + (c.nx + nj.nx) / denom * bw,
                  z: vz + (c.nz + nj.nz) / denom * bw,
                };
            }
          return {
            x: vx + c.nx * bw,
            z: vz + c.nz * bw,
          };
        }
      for (i in 0...list.length)
        {
          var c = list[i];
          var oA = outer(i, 0);
          var oB = outer(i, 1);
          // v runs across the strip and u along the run, so the edging's grain follows the kerb
          var ul = Math.sqrt((c.bx - c.ax) * (c.bx - c.ax) + (c.bz - c.az) * (c.bz - c.az)) / bt;
          MeshBufTools.quad(b, [c.ax, yTop, c.az], [oA.x, yTop, oA.z], [oB.x, yTop, oB.z],
            [c.bx, yTop, c.bz], [0, 1, 0, 0, ul, 0, ul, 1]);
          MeshBufTools.quad(b, [oA.x, yBot, oA.z], [oB.x, yBot, oB.z], [oB.x, yTop, oB.z],
            [oA.x, yTop, oA.z], [0, 0, ul, 0, ul, 1, 0, 1]);
        }
    }
}
