package render.military;

import three.Three;
import render.Models;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityModel;

// an opening left in one side of a ring of bags
typedef BagDoor = {
  dir:Int,   // the side it is in: 0 the -z run, 1 +z, 2 -x, 3 +x
  a0:Float,  // where it starts along that side, world
  a1:Float,  // and where it ends
};

// the base's sandbag walls as places for ONE instanced bag (RenderConfig.MODELS.militarySandbag,
// models-src/military/basekit_build.py): a ring of courses round a rect in running bond, each bag
// turned and nudged a little off a hash so a stack does not read as a ruled block. They replace a
// tiling sandbag sheet on emitted slabs, which did not wrap and read as a painted box
class MilitaryBags
{
  // one bag as modelled: its length along local x, its width (a wall's thickness) and its height (a
  // course)
  public static inline var L = 1.2;
  public static inline var W = 0.6;
  public static inline var H = 0.32;
  // how far a bag strays off true: a turn, and a nudge along and across its run
  static inline var TURN = 0.07;
  static inline var NUDGE = 0.05;

// lay `courses` round the rect `r`, its OUTER face, standing on `y`, leaving `door` open
  public static function ring(out:Array<PropPlace>, r:Rect, y:Float, courses:Int,
      ?door:BagDoor):Void
    {
      for (k in 0...courses)
        {
          var cy = y + k * H;
          var odd = (k % 2 == 1);
          // the two runs along x take the corners, the two along z fit between them
          run(out, true, r.z0 + W / 2, r.x0, r.x1, cy, odd, 0, door);
          run(out, true, r.z1 - W / 2, r.x0, r.x1, cy, odd, 1, door);
          run(out, false, r.x0 + W / 2, r.z0 + W, r.z1 - W, cy, odd, 2, door);
          run(out, false, r.x1 - W / 2, r.z0 + W, r.z1 - W, cy, odd, 3, door);
        }
    }

// one course of one side: bags end to end over a0..a1 at `p` across it. The span is split into
// whole bags, so a bag stands a little long or short of its model; an ODD course is offset half a
// bag, its two end bags pushed back inside the span, which is the running bond
  static function run(out:Array<PropPlace>, alongX:Bool, p:Float, a0:Float, a1:Float, y:Float,
      odd:Bool, dir:Int, door:BagDoor):Void
    {
      if (a1 - a0 < L / 2)
        return;
      var n = Std.int(Math.max(1, Math.round((a1 - a0) / L)));
      var pitch = (a1 - a0) / n;
      for (i in 0...(odd ? n + 1 : n))
        {
          var a = a0 + pitch * (odd ? i : i + 0.5);
          a = Math.max(a0 + L / 2, Math.min(a1 - L / 2, a));
          if (door != null &&
              door.dir == dir &&
              a + L / 2 > door.a0 &&
              a - L / 2 < door.a1)
            continue;
          var h = FacilityModel.mix((Std.int(a * 97) * 27644437) ^ (Std.int(p * 131) * 67867979) ^
            Std.int(y * 53));
          var turn = ((h % 1000) / 1000 - 0.5) * 2 * TURN;
          var along = (((h >> 10) % 1000) / 1000 - 0.5) * 2 * NUDGE;
          var across = (((h >> 20) % 1000) / 1000 - 0.5) * 2 * NUDGE;
          out.push({
            x: (alongX ? a + along : p + across),
            z: (alongX ? p + across : a + along),
            yaw: (alongX ? 0.0 : Math.PI / 2) + turn,
            y: y,
          });
        }
    }

// one batch of bags
  public static function batch(scene:Scene, places:Array<PropPlace>):InstancedProp
    {
      return Models.instanced(scene, RenderConfig.MODELS.militarySandbag, places, H, SOLID);
    }
}
