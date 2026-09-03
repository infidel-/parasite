package render.facility;

import three.Three;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Wall;
import render.world.ContactMaskOpts;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the two pieces of fake ambient occlusion the compound's interior gets, and they are fake for the
// same reason and different SHAPES for a reason of their own.
//
// `masonry` is the floor crease, and it emits no geometry at all — it hands rectangles to
// render.world.ContactMask, which blurs them into a field the floor materials sample. THE QUAD
// VERSION WAS BUILT FIRST AND SHIPPED BROKEN — one gradient quad per wall face, the shape
// render.sewer.SewerDetail and render.world.roofs.RoofShadows both use — and it failed on a fact
// this file's own `slab` call makes obvious in hindsight: a sewer wall face IS the cell boundary, so
// its strips tile, while a facility wall is a SLAB that insets by (CELL - thick)/2 wherever the wall
// line does not carry. Counting how many strips covered each point along one straight run measured
// `111...1111211132` — a GAP at every inset, a DOUBLE or TRIPLE at every notch, and since a quad's
// alpha is uniform along its run, every one of those steps was a hard edge. Reported from the game
// as missing corners and lines beside doors; the band was in fact discontinuous everywhere.
//
// `corners` is the vertical line where two wall faces meet, and it is QUADS, which is not a
// contradiction of the above. A field cannot do it at all: ContactMask is top-down, so every
// fragment of a 6-unit wall face samples the same xz and the whole column would darken flat. And the
// tiling failure that killed the floor strips cannot happen here, because a corner is a POINT
// feature and not a RUN — each strip stands on one face of one notch, meets nothing, and has nothing
// to fail to meet.
class FacilityDetail
{
// every rectangle of masonry in the compound, as the SOLID boxes and the HOLES punched back out of
// them. ContactMask paints them in that order.
//
// two subtleties, both of them the reason this returns rects rather than a per-cell predicate:
//   A WALL CELL IS THE UNION OF ITS RUNS, NEVER ITS BOUNDING BOX. `slab` is the box, and at a corner
//     or a T it is strictly bigger than the masonry — the difference is exactly `notches`, so the
//     boxes go in as solid and the notches come back out as holes. Erasing them is also what puts
//     the blur round an inside corner, which is where the quad version needed a radial it never got.
//   A DOORWAY HOLDS NO MASONRY AT FLOOR LEVEL. `carries` counts a door cell so the wall line reads
//     as continuous through it — right for the shell, which has a lintel to emit up at DOOR_H, and
//     wrong down here. Skipping it is the whole of the doorway behaviour: no masonry, no darkening,
//     and the band fades out into the opening over the blur width with nothing special written for it
  public static function masonry(m:Facility):{ solid:Array<ContactRect>, holes:Array<ContactRect> }
    {
      var solid:Array<ContactRect> = [];
      var holes:Array<ContactRect> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!FacilityModel.isWall(m, col, row) ||
                FacilityModel.isDoor(m, col, row))
              continue;
            solid.push(FacilityGeom.slab(m, col, row));
            for (n in FacilityGeom.notches(m, col, row))
              holes.push(n);
          }
      return {
        solid: solid,
        holes: holes,
      };
    }

// a dark strip up each face of every reentrant corner, all of them in ONE merged mesh.
//
// THE CORNERS ARE ALREADY ENUMERATED and this walks the same list render.facility.FacilityGrime
// does, under the same guards. A reentrant corner IS a notch: a wall cell whose line carries both
// ways is an L, `FacilityGeom.notches` punches the square out of its angle, and the two sides of
// that square are the masonry the room's own corner is made of. Deriving it any other way would be
// re-deriving that.
//
// MERGED and not instanced, which is where this parts company with the tunnels' port. Down there the
// corner strips ride the floor strips' own InstancedMesh for free; up here the floor strips do not
// exist — a field replaced them — so there is no batch to ride and the choice is free. One merged
// mesh is one draw call for the whole compound however many corners it has, where an InstancedMesh
// would be the same call plus a per-frame cull it does not need on static geometry.
  public static function corners(scene:Scene, m:Facility):Void
    {
      var b = MeshBufTools.make();
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            // the grime band's own gate, and for the same three reasons: a WINDOW cell's face is cut
            // into a sill run and a head run, a SHUTTER is the hangar's roll-up door, and the hangar
            // is a working shed rather than a finished interior
            if (!FacilityModel.isWall(m, col, row) ||
                m.wall[row][col] != Wall.SOLID ||
                m.structures[m.owner[row][col]].hangar)
              continue;
            for (nt in FacilityGeom.notches(m, col, row))
              {
                if (!FacilityModel.isIndoor(m, nt.col, nt.row))
                  continue;
                // the two planes the notch leaves facing the room, and the point they meet at —
                // which is the corner both strips are opaque at. same pair FacilityGeom's `butt`
                // emits as geometry and FacilityGrime bands
                var cx = (nt.dx == 3 ? nt.x0 : nt.x1);
                var cz = (nt.dz == 1 ? nt.z0 : nt.z1);
                // EACH STRIP STARTS CORNER_EPS OUT FROM THE CORNER, by the same gap it stands off
                // its own wall by, so the two MEET IN PLAN instead of crossing. Run to the corner
                // itself and each one's fully-opaque edge overhangs the other's plane by that gap —
                // and since both are transparent with depthWrite off, the overhanging sliver blends
                // straight through its twin and lays a hard 0.75 line down the corner. Shipped that
                // way once and reported from the game as exactly that
                var e = FacilityStyle.CORNER_EPS;
                post(b, nt.dx, {
                  x0: cx,
                  x1: cx,
                  z0: nt.z0 + (nt.dz == 1 ? e : 0),
                  z1: nt.z1 - (nt.dz == 1 ? 0 : e),
                }, cx, cz);
                post(b, nt.dz, {
                  x0: nt.x0 + (nt.dx == 3 ? e : 0),
                  x1: nt.x1 - (nt.dx == 3 ? 0 : e),
                  z0: cz,
                  z1: cz,
                }, cx, cz);
              }
          }
      add(scene, b);
    }

// one strip: the whole height of one notch face, opaque where that face meets its perpendicular twin
// and fading to nothing over the notch's own length.
//
// THE GRADIENT RUNS ALONG THE FACE, NOT UP IT, which is the whole of the uv here. Textures
// .makeShadowGradient is a 4x64 vertical ramp, opaque at v = 0, and every other user hangs it the
// way it was drawn; this one turns it on its side. So `u` is a constant — the ramp is four texels
// wide and carries no shape across them — and `v` is 0 at the corner and 1 at the far end.
//
// WHICH end is the corner is measured rather than cased. `ends` winds a face differently per `dir`
// so that the front face looks the right way, and hand-casing which of its two returns is the near
// one would be re-deriving that table backwards; taking the nearer of the two to the corner point
// cannot get it wrong and does not care if `ends` is ever retuned
  static function post(b:MeshBuf, dir:Int, s:FacilityGeom.Rect, cx:Float, cz:Float):Void
    {
      var p = FacilityGeom.plane(s, dir, FacilityStyle.CORNER_EPS);
      var e = FacilityGeom.ends(p.x0, p.x1, p.z0, p.z1, dir);
      var da = (e[0] - cx) * (e[0] - cx) + (e[1] - cz) * (e[1] - cz);
      var db = (e[2] - cx) * (e[2] - cx) + (e[3] - cz) * (e[3] - cz);
      var va = (da <= db ? 0.0 : 1.0);
      var vb = 1.0 - va;
      var h = FacilityStyle.WALL_H;
      MeshBufTools.quad(b, [e[0], 0, e[1]], [e[2], 0, e[3]], [e[2], h, e[3]], [e[0], h, e[1]],
        [0.5, va, 0.5, vb, 0.5, vb, 0.5, va]);
    }

// every strip in the compound as ONE mesh.
//
// BASIC and not Lambert, unlike the grime band beside it: this is not a surface taking the room's
// light, it is the absence of light, and a lit black quad would brighten with the wall it is meant
// to be darkening. It is the tunnels' own choice for the same quads.
//
// FrontSide matters and is worth a draw call: three renders a transparent DoubleSide material as TWO
// single-side passes, measured 36 -> 34 in the habitat. Each strip faces the room it is in and is
// never seen from behind.
//
// `transparent` is set AFTER VisionMask.patch, the order render.facility.FacilityGeom.addPane and
// FacilityGrime both need: the mask reads that flag at patch time to choose its branch, and set
// first it would fade a hidden strip OUT rather than sinking it toward the fog with its wall
  static function add(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = VisionMask.patch(new MeshBasicMaterial({
        color: 0x000000,
        alphaMap: Textures.makeShadowGradient(),
        opacity: FacilityStyle.CORNER_ALPHA,
        depthWrite: false,
        side: THREE.FrontSide,
      }));
      mat.transparent = true;
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
