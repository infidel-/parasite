package render.corp;

import three.Three;
import render.corp.CorpFurniture.CorpArch;
import render.corp.CorpFurniture.CorpFit;
import render.facility.FacilityDeco;
import render.facility.FacilityModel;
import render.facility.FacilityStyle;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// THE ARCHIVE'S LOAD: what is stacked on the records room's casework.
//
// Two meshes for the whole room — board and paper — because everything here is a box and a box is
// axis-aligned quads, which is docs/3d-geometry.md's own triage. Nothing on this pass is a
// silhouette and nothing earns a glb: the file cabinet and the shelving unit are glbs because a
// DRAWER and a BOARD stand proud of a carcass, and a carton standing on a lid has no such feature.
//
// IT IS NOT render.facility.FacilityClutter.lid, and that was a decision. Its `pick` list drags the
// compound's lab glassware sheet in as a fifth material, its `o.store` size band is fitted to a
// 3.9 x 1.8 pallet bay, and it is a FREE-YAW rejection sampler -- which is the whole difference
// between a records room and a jumble sale. What this calls instead are the two functions that were
// already public: FacilityDeco.crate for a sealed carton and for a bare ream (four paper edges and
// a paper top IS a stack of paper), and FacilityDeco.openBox, added beside it for the one thing the
// compound has never needed -- a box with its lid off and its contents showing.
//
// THE BOXES ARE SQUARED UP TO THEIR UNIT. `crate` takes a free turn and the compound's shelving
// uses it (DECO_BOX_YAW, ~14 degrees), for the stated reason that a rank of square-on cuboids reads
// as one machined object. An archive is the case where that reasoning inverts: filing is the act of
// squaring things up, and a records room whose boxes are all askew reads as a room being moved out
// of. So every box takes its unit's own yaw exactly, and what separates two of them is their size,
// their height and their phase into the sheet.
//
// and it is merged through FacilityDeco.solid and NOT FacilityGeom.add, which is not
// interchangeable here: `solid` derives `vertexColors` from the buffer's own colour channel and
// `add` does not, so a crate merged the other way would silently lose every bit of the shading it
// carries -- and that shading is all the shading it can get (FacilityStyle.DECO_BOX_AO_LOW).
class CorpArchive
{
// stack every archive unit on the plate. AFTER render.corp.CorpFurniture, which is what places the
// units this reads, and the counters go back into ITS CorpFit -- the merged meshes have no instance
// count anywhere and __corp() is the only handle on either
  public static function build(scene:Scene, n:CorpFit):Void
    {
      var board = MeshBufTools.make();
      var paper = MeshBufTools.make();
      for (u in CorpFurniture.units)
        load(u, board, paper, n);
      FacilityDeco.solid(scene, board, CorpStyle.ARCH_BOARD, false);
      FacilityDeco.solid(scene, paper, CorpStyle.ARCH_PAPER, false);
    }

// one unit's load: up to CorpStyle.ARCH_LOAD_MAX pieces across each of its levels
  static function load(u:CorpArch, board:MeshBuf, paper:MeshBuf, n:CorpFit):Void
    {
      var f = CorpFurniture.ARCH[u.fam];
      // the unit's own two axes off its yaw, which render.corp.CorpFurniture.archive built as
      // atan2(dx(front), dz(front)): the front NORMAL is (sin, cos), so the width it stands along
      // -- the one a load is dealt over -- is that turned a quarter, (cos, -sin)
      var wx = Math.cos(u.yaw), wz = -Math.sin(u.yaw);
      var span = f.w - 2 * CorpStyle.ARCH_GAP;
      var g = u.seed;
      for (lv in 0...f.levels.length)
        {
          var h = FacilityModel.mix(g ^ ((lv + 1) * 40503));
          if (h % 100 >= CorpStyle.ARCH_LOAD_CHANCE)
            continue;
          var cnt = 1 + (h >>> 7) % CorpStyle.ARCH_LOAD_MAX;
          var slot = span / cnt;
          for (k in 0...cnt)
            {
              var hh = FacilityModel.mix(h ^ ((k + 1) * 1103515245));
              // the piece's size, CAPPED BY ITS SLOT and not scaled to it: three on one level are
              // three small boxes and never three overlapping ones
              var bw = Math.min(CorpStyle.ARCH_BOX_W +
                ((hh % 1000) / 1000) * CorpStyle.ARCH_BOX_W_VAR, slot * 0.9);
              var bd = Math.min(bw, f.d * CorpStyle.ARCH_BOX_D);
              var bh = CorpStyle.ARCH_BOX_H +
                (((hh >>> 10) % 1000) / 1000) * CorpStyle.ARCH_BOX_H_VAR;
              var kind = (hh >>> 21) % 3;
              if (kind == 1)
                bh *= CorpStyle.ARCH_REAM_H;
              // AND THE BAY IS A CEILING. The racking's shelves are 0.827 apart against a band
              // that rolls up to 0.85, so uncapped a carton grows through the plate over it; the
              // last bay is closed by the frame's top rail and not by a shelf, which is what
              // ArchUnit.head carries. A lid has neither and takes no cap
              var ceil = (lv + 1 < f.levels.length ? f.levels[lv + 1] : f.head);
              if (ceil > 0)
                bh = Math.min(bh, ceil - f.levels[lv] - CorpStyle.ARCH_HEAD_GAP);
              var off = -span / 2 + (k + 0.5) * slot;
              var o = {
                cx: u.x + wx * off,
                cz: u.z + wz * off,
                hw: bw / 2,
                hd: bd / 2,
                y0: f.levels[lv],
                y1: f.levels[lv] + bh,
                yaw: u.yaw,
                ph: (kind == 1 ? 0.0 : ((hh >>> 3) % 1000) / 1000 * 4.0),
                tileU: (kind == 1 ? CorpStyle.ARCH_REAM_TILE : null),
                // and how much light the level gets, ramped up the unit from
                // FacilityStyle.DECO_BOX_AO_LOW at the bottom bay to 1.0 at the top -- the
                // compound's own arithmetic, for its own reason: an open frame is closed above
                // every shelf but its last, so the bay's lid is the occluder and the top takes
                // none of it. A unit whose only level is its LID has nothing over it at all and
                // takes the flat 1.0; what a box there still gets is `crate`'s foot darkening
                ao: (f.levels.length > 1
                  ? FacilityStyle.DECO_BOX_AO_LOW + (1.0 - FacilityStyle.DECO_BOX_AO_LOW) *
                    lv / (f.levels.length - 1)
                  : 1.0),
              };
              switch (kind)
                {
                  // a sealed carton, and a bare ream -- the SAME emitter into a different buffer,
                  // which is the whole of "four paper edges and a paper top is a stack of paper"
                  case 1:
                    FacilityDeco.crate(paper, o);
                    n.sheaves++;

                  case 2:
                    FacilityDeco.openBox(board, paper, o);
                    n.boxes++;

                  default:
                    FacilityDeco.crate(board, o);
                    n.boxes++;
                }
            }
        }
    }
}
