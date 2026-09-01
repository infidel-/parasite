package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityGeom.Shell;
import render.facility.FacilityModel.Facility;
import render.world.MeshBuf.MeshBufTools;

// one thing standing on a roof: where it is, what it is, and which structure's deck it stands on.
// the structure is what drives its visibility — see `mask` — and it is in __facility().roof because
// an instanced batch carries no userData.cls, so render.Debug.find cannot reach a condenser
typedef RoofProp = {
  col:Int,
  row:Int,
  kind:String,      // 'ac' | 'dish'
  structure:Int,
};

// one hangar's barrel vault, as the numbers it was DERIVED from rather than as geometry. every
// question an arch raises is numeric and a screenshot cannot answer any of them: is the section
// really a circle segment (radius against span and rise), how much of a circle is it actually
// taking, did the ridge pick the long axis, did both gable crescents emit
typedef Vault = {
  structure:Int,
  span:Float,        // the chord, outer wall plane to outer wall plane across the SHORT axis
  rise:Float,        // the segment height over that chord
  radius:Float,
  arcDeg:Float,      // the whole subtended angle — a half-round barrel would read 180
  seg:Int,
  quads:Int,         // the arch itself, in the FADING deck
  gables:Int,        // and the two crescents closing its ends, in the structure's own WALL buffer
  ridgeAlongX:Bool,
  // how long the ridge is. `span` alone cannot catch a box fitted to the wrong rect — see `ring`,
  // where a door in the wall ring stretched exactly this and left the span correct
  ridge:Float,
};

// the vault's section, derived once and read by both halves of it — the arch, which fades with the
// deck, and the gable crescents, which are cladding and stay with the walls
typedef Arc = {
  alongX:Bool,          // does the ridge run along x
  a0:Float,             // the ridge's two ends, on the outer masonry planes
  a1:Float,
  cs:Array<Float>,      // the arc, per node: its coordinate on the CROSS axis
  ys:Array<Float>,      // and its height
  span:Float,
  rise:Float,
  r:Float,
  theta:Float,          // HALF the subtended angle
};

// the two instanced batches, what they stand on, and how many hatches were built
typedef Roof = {
  ac:Models.InstancedProp,
  dish:Models.InstancedProp,
  // index-aligned with each batch's own placements: which structure that instance stands on
  acOf:Array<Int>,
  dishOf:Array<Int>,
  props:Array<RoofProp>,
  hatches:Int,
  vaults:Array<Vault>,
};

// what stands on a facility building's roof: condenser units, one comms dish and one access hatch
// per building, inside the parapet.
//
// the CITY answers this question with top-down sprite decals (render.world.roofs.RoofDetails) and
// this deliberately does not: a decal is flat, and the facility's roofs are the one place in the
// game the camera looks down ONTO rather than past, so a condenser lying flat on the deck reads as a
// stain. two of these are real props and the third is merged geometry, which is the same
// silhouette-vs-surface split every other object in this compound was decided on (see the header of
// render.facility.FacilityEntry).
//
// RENDER-ONLY and derived, like the cars and the gate: nothing is stamped on the tiles, so every
// compound already saved grows its plant the moment it is drawn again.
//
// NO VISION MASK on any of it, and that is the roof's own rule rather than an oversight. the roof is
// the one surface whose visibility is decided by where the player STANDS and not by what they can
// see (FacilityGeom.structure's call to addDeck says why); a masked condenser over cells the LOS
// sweep never reached would sink to the fog colour while the deck under it stayed solid
class FacilityRoof
{
  static inline var CELL = CityConfig.CELL;
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// every roof in the compound, and the two kinds are not variations of one thing. a LAB BUILDING is a
// parapeted box with a flat deck and objects standing on it; a HANGAR is a shed, so it takes no
// parapet, carries nothing, and its roofline IS its roof — the arched vault `vault` springs between
// its long walls, which is the job FacilityGeom.structure's parapet skip has been deferring
  public static function build(scene:Scene, m:Facility, shells:Array<Shell>):Roof
    {
      var acPlaces:Array<Models.PropPlace> = [];
      var dishPlaces:Array<Models.PropPlace> = [];
      var out:Roof = {
        ac: null,
        dish: null,
        acOf: [],
        dishOf: [],
        props: [],
        hatches: 0,
        vaults: [],
      };
      for (si in 0...m.structures.length)
        {
          if (m.structures[si].hangar)
            {
              out.vaults.push(vault(scene, m, si, shells[si]));
              continue;
            }
          // the hatch housing rides the structure's OWN buffer so it can be pushed into Shell.roof
          // and fade with the deck it stands on
          var hatch = MeshBufTools.make();
          fill(m, si, acPlaces, dishPlaces, hatch, out);
          if (hatch.idx.length > 0)
            {
              FacilityGeom.addDeck(scene, hatch, FacilityStyle.COPING, true, shells[si]);
              out.hatches++;
            }
        }
      out.ac = Models.instanced(scene, RenderConfig.MODELS.facilityRoofAc, acPlaces,
        FacilityStyle.ROOF_AC_H, SOLID);
      out.dish = Models.instanced(scene, RenderConfig.MODELS.facilityRoofDish, dishPlaces,
        FacilityStyle.ROOF_DISH_H, SOLID);
      return out;
    }

// one building's roof. the candidates are picked first and the assignment runs over that list, so
// the hatch can take the one nearest the middle without a second pass over the grid
  static function fill(m:Facility, si:Int, acPlaces:Array<Models.PropPlace>,
      dishPlaces:Array<Models.PropPlace>, hatch:render.world.MeshBuf.MeshBuf, out:Roof):Void
    {
      var st = m.structures[si];
      var cand = candidates(m, si);
      if (cand.length == 0)
        return;
      // thin the list to what one roof should carry, by a STRIDE over the whole of it and not by
      // taking the first N. the scan is row-major, so a cap alone spends a big roof's entire
      // allowance on its first two rows: measured on the 31x24 building, all seven objects came
      // back at rows 8 and 9 and the rest of the deck was bare
      var step = Std.int(Math.ceil(cand.length / (FacilityStyle.ROOF_PROP_MAX + 2)));
      if (step > 1)
        cand = [for (i in 0...cand.length) if (i % step == 0) cand[i]];
      // the hatch goes nearest the middle of the roof, where a stair core comes up
      var cx = (st.x1 + st.x2) / 2.0;
      var cy = (st.y1 + st.y2) / 2.0;
      var mid = 0;
      var best = 1e9;
      for (i in 0...cand.length)
        {
          var dx = cand[i].col - cx;
          var dy = cand[i].row - cy;
          if (dx * dx + dy * dy < best)
            {
              best = dx * dx + dy * dy;
              mid = i;
            }
        }
      var dishDone = false;
      for (i in 0...cand.length)
        {
          var col = cand[i].col;
          var row = cand[i].row;
          var h = FacilityModel.mix((col * 70001) ^ (row * 30011));
          var c = CityConfig.cellToWorld(col, row);
          if (i == mid)
            {
              box(hatch, c.x, c.z, h);
              continue;
            }
          // ONE dish per building. it is the roof's silhouette, and two of them read as a repeated
          // prop rather than as the thing this building has on it
          if (h % 3 == 2 &&
              !dishDone)
            {
              dishDone = true;
              dishPlaces.push({
                x: c.x,
                z: c.z,
                yaw: (h >> 8) % 6283 / 1000.0,
                y: FacilityStyle.ROOF_Y,
              });
              out.dishOf.push(si);
              out.props.push({ col: col, row: row, kind: 'dish', structure: si });
              continue;
            }
          acPlaces.push({
            x: c.x,
            z: c.z,
            // a quarter turn and not a free one: a condenser is a manufactured box and stands
            // square to the building, exactly as the parked cars do
            yaw: ((h >> 8) % 4) * (Math.PI / 2),
            y: FacilityStyle.ROOF_Y,
          });
          out.acOf.push(si);
          out.props.push({ col: col, row: row, kind: 'ac', structure: si });
        }
    }

// the cells of this structure's roof something may stand on: interior floor whose four neighbours
// are ALSO this structure's interior floor, thinned to one cell in ROOF_PROP_STEP.
//
// the neighbour test is what keeps everything clear of the wall ring, so nothing can foul the
// parapet standing on it, and it means a prop is always over solid deck rather than over the rim
  static function candidates(m:Facility, si:Int):Array<{ col:Int, row:Int }>
    {
      var st = m.structures[si];
      var out = [];
      for (row in st.y1...st.y2 + 1)
        for (col in st.x1...st.x2 + 1)
          {
            if (!owns(m, si, col, row) ||
                (col * 3 + row) % FacilityStyle.ROOF_PROP_STEP != 0)
              continue;
            var clear = true;
            for (dir in 0...4)
              if (!owns(m, si, col + DC[dir], row + DR[dir]))
                {
                  clear = false;
                  break;
                }
            if (clear)
              out.push({ col: col, row: row });
          }
      return out;
    }

// is this cell this structure's own indoor floor?
  static inline function owns(m:Facility, si:Int, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        m.owner[row][col] == si &&
        FacilityModel.isIndoor(m, col, row);
    }

// the access hatch housing: four clad faces and a lid, standing on the deck. `h` turns it a quarter
// by swapping its two plan dimensions, which is the whole of a yaw for an axis-aligned box.
//
// no underside. it stands ON the deck, and the mesh it goes into does not cast (see addDeck), so
// there is no ray to leak through the bottom the way the guard booth's roof slab had
  static function box(b:render.world.MeshBuf.MeshBuf, x:Float, z:Float, h:Int):Void
    {
      var turn = (h % 2 == 0);
      var w = (turn ? FacilityStyle.HATCH_W : FacilityStyle.HATCH_D) / 2;
      var d = (turn ? FacilityStyle.HATCH_D : FacilityStyle.HATCH_W) / 2;
      var y1 = FacilityStyle.ROOF_Y + FacilityStyle.HATCH_H;
      for (dir in 0...4)
        FacilityGeom.face(b, x - w, x + w, z - d, z + d, dir, FacilityStyle.ROOF_Y, y1,
          FacilityStyle.COPING_TILE);
      FacilityGeom.cap(b, x - w, x + w, z - d, z + d, y1, FacilityStyle.COPING_TILE);
    }

// the hangar's roof: a barrel vault of ribbed sheet metal arching between its two long walls. its
// section is `section` below, and the crescent closing each end is `crescents`, which is CLADDING
// and belongs to the walls rather than to this.
//
// it goes in the FADING buffer, so walking in opens the shed exactly as walking into a lab building
// opens its deck. nothing in FacilityArea.ease has to be told: it eases whatever Shell.roof holds
  static function vault(scene:Scene, m:Facility, si:Int, shell:Shell):Vault
    {
      var s = section(m, si);
      var n = FacilityStyle.HANGAR_ARC_SEG;
      var t = FacilityStyle.HANGAR_ROOF_TILE;
      var b = MeshBufTools.make();
      // the one place that knows which world axis is the ridge and which is the arc
      var put = function(along:Float, y:Float, cross:Float, u:Float, v:Float):Void
        {
          MeshBufTools.vtx(b, (s.alongX ? along : cross), y, (s.alongX ? cross : along), u, v);
        };
      // the vault as a SHARED-VERTEX grid rather than as n loose quads. MeshBufTools.quad pushes
      // four fresh vertices every call and FacilityGeom.geom derives normals with
      // computeVertexNormals, so loose quads shade FLAT — and a faceted barrel is the one failure a
      // curve cannot survive, its whole read being that it is smooth. sharing the columns makes
      // each seam average to the radial normal for free
      for (i in 0...n + 1)
        {
          // v runs on ARC LENGTH and not on the chord projection, which is the whole of "never
          // stretch" on a curve: projected, the ribs would crowd together toward both springings
          var v = (2 * s.theta * i / n) * s.r / t;
          put(s.a0, s.ys[i], s.cs[i], s.a0 / t, v);
          put(s.a1, s.ys[i], s.cs[i], s.a1 / t, v);
        }
      for (i in 0...n)
        {
          var k = 2 * i;
          tri(b, k, k + 1, k + 3);
          tri(b, k, k + 3, k + 2);
        }
      FacilityGeom.addDeck(scene, b, FacilityStyle.ROOF_HANGAR, true, shell);
      return {
        structure: si,
        span: s.span,
        rise: s.rise,
        radius: s.r,
        arcDeg: 2 * s.theta * 180 / Math.PI,
        seg: n,
        quads: n,
        gables: 2 * n,
        ridgeAlongX: s.alongX,
        ridge: Math.abs(s.a1 - s.a0),
      };
    }

// the crescent of masonry closing each end of the vault, between the wall head and the arch.
//
// IT IS NOT ROOFING AND IT IS NOT IN THE ROOF BUFFER. a gable end is the wall carrying on upward, so
// it goes into the structure's OWN wOut buffer at the caller's hand — same cladding, same mesh, same
// world-aligned WALL_TILE course as the masonry it stands on, so it continues the wall's texture
// exactly rather than butting a second material against it, and it costs no draw call. it also then
// STAYS when the player walks in, which is what the parapet ring one building over already does:
// walls do not fade, only the lid over your head does.
//
// loose quads on purpose, unlike the arch: a crescent is PLANAR, so there is no curvature for a
// shared-vertex grid to smooth
  public static function crescents(m:Facility, si:Int, b:render.world.MeshBuf.MeshBuf):Void
    {
      var s = section(m, si);
      var n = FacilityStyle.HANGAR_ARC_SEG;
      var t = FacilityStyle.WALL_TILE;
      var pt = function(along:Float, y:Float, cross:Float):Array<Float>
        {
          return (s.alongX ? [along, y, cross] : [cross, y, along]);
        };
      for (end in 0...2)
        {
          var a = (end == 0 ? s.a0 : s.a1);
          for (i in 0...n)
            {
              var q0 = pt(a, FacilityStyle.ROOF_Y, s.cs[i]);
              var q1 = pt(a, s.ys[i], s.cs[i]);
              var q2 = pt(a, s.ys[i + 1], s.cs[i + 1]);
              var q3 = pt(a, FacilityStyle.ROOF_Y, s.cs[i + 1]);
              // u on the CROSS axis and v on y, both over WALL_TILE — FacilityGeom.face's own
              // mapping for a wall running this way, which is what makes the join invisible
              var u0 = s.cs[i] / t, u1 = s.cs[i + 1] / t;
              var w = FacilityStyle.ROOF_Y / t;
              // wound to look OUT along the ridge, so the far end takes the cycle backwards
              if (end == 0)
                MeshBufTools.quad(b, q0, q1, q2, q3,
                  [u0, w, u0, s.ys[i] / t, u1, s.ys[i + 1] / t, u1, w]);
              else
                MeshBufTools.quad(b, q3, q2, q1, q0,
                  [u1, w, u1, s.ys[i + 1] / t, u0, s.ys[i] / t, u0, w]);
            }
        }
    }

// the arch's section, from the structure's own wall ring and the two constants and nothing else.
//
// THE SECTION IS A CIRCULAR SEGMENT: for a chord S and a segment height H the tangent-chord angle
// gives tan(theta / 2) = H / (S / 2), so theta = 2 * atan(2H / S) is HALF the subtended angle,
// R = (S / 2) / sin(theta), and the centre sits at ROOF_Y + H - R, well below the springing
  public static function section(m:Facility, si:Int):Arc
    {
      var r0 = ring(m, si);
      // the ridge takes the LONGER span and the arc crosses the shorter one, which is
      // render.world.roofs.Gables' rule for a pitched roof. it is also what puts the arch over the
      // DOORS: game.FacilityAreaGenerator.generateHangar draws its shutter row across the short wall
      var alongX = (r0.x1 - r0.x0) >= (r0.z1 - r0.z0);
      var a0 = (alongX ? r0.x0 : r0.z0), a1 = (alongX ? r0.x1 : r0.z1);
      var c0 = (alongX ? r0.z0 : r0.x0), c1 = (alongX ? r0.z1 : r0.x1);
      var span = c1 - c0;
      var cc = (c0 + c1) / 2;
      var rise = Math.min(span * FacilityStyle.HANGAR_RISE_FRAC, FacilityStyle.HANGAR_RISE_MAX);
      var theta = 2 * Math.atan(2 * rise / span);
      var r = (span / 2) / Math.sin(theta);
      var cy = FacilityStyle.ROOF_Y + rise - r;
      var n = FacilityStyle.HANGAR_ARC_SEG;
      // WHICH WAY THE ARC IS WALKED IS NOT COSMETIC. the two orientations map (along, cross) onto
      // (x, z) with opposite handedness, so one winding rule would emit an upward-facing vault for
      // one and a downward-facing — i.e. INVISIBLE, `addDeck` being FrontSide — one for the other.
      // walking the arc backwards when the ridge runs along x cancels that, so the winding at both
      // call sites is written once. cos is even, so the heights are untouched by the sign
      var sgn = (alongX ? -1.0 : 1.0);
      var cs = [], ys = [];
      for (i in 0...n + 1)
        {
          var phi = sgn * (2 * theta * i / n - theta);
          cs.push(cc + r * Math.sin(phi));
          ys.push(cy + r * Math.cos(phi));
        }
      return {
        alongX: alongX,
        a0: a0,
        a1: a1,
        cs: cs,
        ys: ys,
        span: span,
        rise: rise,
        r: r,
        theta: theta,
      };
    }

// the structure's WALL RING as a world rect, pulled in to the OUTER MASONRY PLANE — the same plane
// the lab buildings' parapets stand on, so the compound has one roofline rule and the vault springs
// exactly where a coping would have sat.
//
// it is measured off the cells this structure OWNS and NOT off st.ox1..ox2, which is the flood
// fill's own bbox grown by one cell and is wrong the moment a doorway sits in the ring. a door cell
// finalises to plain corridor lino, so isIndoor calls it indoors and the fill's bbox ALREADY reaches
// into the masonry there; growing that by another cell puts the box a whole cell outside the wall on
// that side alone. measured on the generated compound: the hangar's own side door at col 44 took
// ox1 to 43 and the vault overhung its west gable by exactly one cell, 4 world units, with the other
// three sides landing correctly — which is what an asymmetric error looks like from the game camera
  static function ring(m:Facility, si:Int):{ x0:Float, x1:Float, z0:Float, z1:Float }
    {
      var st = m.structures[si];
      var c0 = st.ox2, c1 = st.ox1, r0 = st.oy2, r1 = st.oy1;
      for (row in st.oy1...st.oy2 + 1)
        for (col in st.ox1...st.ox2 + 1)
          {
            if (!FacilityModel.inside(m, col, row) ||
                m.owner[row][col] != si)
              continue;
            if (col < c0)
              c0 = col;
            if (col > c1)
              c1 = col;
            if (row < r0)
              r0 = row;
            if (row > r1)
              r1 = row;
          }
      var half = (CityConfig.GRID * CELL) / 2;
      var e = FacilityStyle.PARAPET_INSET;
      return {
        x0: c0 * CELL - half + e,
        x1: (c1 + 1) * CELL - half - e,
        z0: r0 * CELL - half + e,
        z1: (r1 + 1) * CELL - half - e,
      };
    }

// three indices straight into a buffer's own vertex list, for geometry built as a shared grid rather
// than as loose quads — MeshBufTools has no emitter for that, every other surface in the game being
// flat enough not to want one
  static inline function tri(b:render.world.MeshBuf.MeshBuf, i0:Int, i1:Int, i2:Int):Void
    {
      b.idx.push(i0);
      b.idx.push(i1);
      b.idx.push(i2);
    }

// which instances may draw this frame: an instance goes when the deck it stands on has faded far
// enough that it would be left hanging in the air.
//
// a hard cut and not a fade — the roof takes REVEAL_MULT * BASE_MS to go, so a prop pops partway
// through it. cross-fading an InstancedMesh needs a per-instance alpha attribute and its own shader
// patch, which is a lot of machinery for a prop the player is walking under at the time
// (ponytail: add it if the pop reads badly)
  public static function mask(of:Array<Int>, reveal:Array<Float>):Array<Bool>
    {
      return [for (si in of) reveal[si] < 0.5];
    }
}
