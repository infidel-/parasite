package render.facility;

import three.Three;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Wall;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the damp band at the foot of every INTERIOR wall face, and nothing else. ported from
// render.sewer.SewerDetail.grime, itself the same strip render.world.Buildings puts along a city
// wall at street level. zero art: `decals/grime-2` already ships for both.
//
// this exists because `facility/wall-interior` measures sd 3.00 and `facility/floor-lino` sd 2.37 —
// the flattest large surfaces in the game. No tiling period puts detail on an 8x24-unit corridor
// ribbon; the contrast has to be PLACED, which is the same argument the lobby notice board is built
// on (render.facility.FacilityBoard).
//
// A CRACK LAYER WAS BUILT ALONGSIDE THIS AND CUT. It rode the same pass over the same faces for one
// more draw call, and it was answering the wrong question about the place: this is a working
// research facility at the start of the game, not a ruin. `decals/wall-crack-2` turned out to be an
// impact SPALL — a hole blown out of concrete — and even `-1`'s hairline says the building is coming
// apart, which nothing else in the compound says. Mopping wear does not.
//
// one merged mesh for the whole compound, so the band costs ONE draw call however big the building
class FacilityGrime
{
// every interior wall face's band into one mesh. returns how many faces took one, for __facility()
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            // SOLID cells only. a WINDOW cell's face is cut into a sill run and a head run, a SHUTTER
            // is the hangar's roll-up door, and a doorway carries no masonry down here at all
            if (!FacilityModel.isWall(m, col, row) ||
                m.wall[row][col] != Wall.SOLID ||
                m.structures[m.owner[row][col]].hangar)
              continue;
            var s = FacilityGeom.slab(m, col, row);
            for (dir in 0...4)
              {
                var nc = col + FacilityGeom.DC[dir];
                var nr = row + FacilityGeom.DR[dir];
                // the same face set FacilityGeom.structure emits a `face()` on, narrowed to the ones
                // its own `look` closure paints in an INTERIOR texture: the wall line does not carry
                // this way, and what it looks at is indoor floor
                if (FacilityGeom.carries(m, nc, nr) ||
                    !FacilityModel.isIndoor(m, nc, nr))
                  continue;
                band(b, dir, s);
                n++;
              }
          }
      add(scene, b);
      return n;
    }

// one band over a WHOLE face, floor to GRIME_H, standing GRIME_EPS proud of the masonry.
//
// it cannot go through FacilityGeom.face, which maps u and v on ONE period: u is world-derived here
// so the muck runs continuously from cell to cell and never stretches, while v spans the ramp
// EXACTLY ONCE, which is what the clamped wrapT on the texture is for.
//
// the face plane is the SLAB's and never the cell's — a wall is 2 units of masonry in a 4-unit cell,
// so a band on the cell boundary would float a unit inside the room — and its run is the slab's own,
// which at a corner or a jamb is genuinely shorter than a cell
  static function band(b:MeshBuf, dir:Int, s:FacilityGeom.Rect):Void
    {
      var e = FacilityStyle.GRIME_EPS;
      // the face plane pushed `e` out into the room, as the degenerate rect FacilityGeom.ends winds
      // a quad against. the four cases are the one thing here that is invisible when it is wrong: a
      // band emitted against dir 2 where the emitter meant dir 3 lands inside the masonry
      var p:FacilityGeom.Rect = switch (dir)
        {
          case 0: { x0: s.x0, x1: s.x1, z0: s.z0 - e, z1: s.z0 - e };
          case 1: { x0: s.x0, x1: s.x1, z0: s.z1 + e, z1: s.z1 + e };
          case 2: { x0: s.x0 - e, x1: s.x0 - e, z0: s.z0, z1: s.z1 };
          default: { x0: s.x1 + e, x1: s.x1 + e, z0: s.z0, z1: s.z1 };
        };
      var q = FacilityGeom.ends(p.x0, p.x1, p.z0, p.z1, dir);
      var t = FacilityStyle.GRIME_TILE;
      var us = (dir < 2 ? q[0] : q[1]) / t;
      var ue = (dir < 2 ? q[2] : q[3]) / t;
      var h = FacilityStyle.GRIME_H;
      MeshBufTools.quad(b, [q[0], 0, q[1]], [q[2], 0, q[3]], [q[2], h, q[3]], [q[0], h, q[1]],
        [us, 0, ue, 0, ue, 1, us, 1]);
    }

// every band in the compound as ONE mesh.
//
// premultiplied, which comes with the hand-painted alpha: a source painted this way carries
// saturated junk RGB under its near-transparent texels, and straight-alpha filtering bleeds that out
// as coloured specks once minified. wrapT clamps because v spans the ramp exactly once.
//
// `transparent` is set AFTER VisionMask.patch, the same order render.facility.FacilityGeom.addPane
// needs and for the same reason: the mask reads that flag at patch time to choose its branch, and
// set first it would fade a hidden band OUT rather than sinking it toward the fog with its wall
  static function add(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var t = Textures.loadTexture(FacilityStyle.GRIME, 'wall');
      t.premultiplyAlpha = true;
      t.wrapT = THREE.ClampToEdgeWrapping;
      t.needsUpdate = true;
      var mat = VisionMask.patch(new MeshLambertMaterial({
        map: t,
        premultipliedAlpha: true,
        opacity: FacilityStyle.GRIME_OPACITY,
        depthWrite: false,
        side: THREE.FrontSide,
      }));
      mat.transparent = true;
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
