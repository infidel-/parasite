package render.world;

// a growable position/uv/index buffer for hand-built merged geometry, plus the two emitters every
// world builder needs. one buffer becomes one BufferGeometry and therefore one draw call, which is
// how the ground, the road markings and the sewer tunnels all stay at a handful of calls each.
// extracted from render.world.Ground so render.sewer.SewerGeom does not re-write the same emitters
typedef MeshBuf = { pos:Array<Float>, uv:Array<Float>, idx:Array<Int> };

class MeshBufTools
{
// append one vertex (position + uv)
  public static function vtx(b:MeshBuf, x:Float, y:Float, z:Float, u:Float, v:Float):Void
    {
      b.pos.push(x);
      b.pos.push(y);
      b.pos.push(z);
      b.uv.push(u);
      b.uv.push(v);
    }

// append one triangle from 3 [x,y,z] points and 6 flat uv floats
  public static function tri(b:MeshBuf, p0:Array<Float>, p1:Array<Float>, p2:Array<Float>, uv:Array<Float>):Void
    {
      var base = Std.int(b.pos.length / 3);
      vtx(b, p0[0], p0[1], p0[2], uv[0], uv[1]);
      vtx(b, p1[0], p1[1], p1[2], uv[2], uv[3]);
      vtx(b, p2[0], p2[1], p2[2], uv[4], uv[5]);
      b.idx.push(base);
      b.idx.push(base + 1);
      b.idx.push(base + 2);
    }

// append one quad from 4 [x,y,z] points (wound p0-p1-p2-p3) and 8 flat uv floats
  public static function quad(b:MeshBuf, p0:Array<Float>, p1:Array<Float>, p2:Array<Float>, p3:Array<Float>, uv:Array<Float>):Void
    {
      var base = Std.int(b.pos.length / 3);
      vtx(b, p0[0], p0[1], p0[2], uv[0], uv[1]);
      vtx(b, p1[0], p1[1], p1[2], uv[2], uv[3]);
      vtx(b, p2[0], p2[1], p2[2], uv[4], uv[5]);
      vtx(b, p3[0], p3[1], p3[2], uv[6], uv[7]);
      b.idx.push(base);
      b.idx.push(base + 1);
      b.idx.push(base + 2);
      b.idx.push(base);
      b.idx.push(base + 2);
      b.idx.push(base + 3);
    }

// a fresh empty buffer
  public static function make():MeshBuf
    {
      return { pos: [], uv: [], idx: [] };
    }
}
