package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.ContactMask;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// one run of corridor casework, as `runs` walks it off the grid
typedef CaseRun = {
  // the run's FIRST cell — the corridor floor cell the first cabinet stands on, not the wall's
  col:Int,
  row:Int,
  // which of that cell's four sides the masonry is on, in render.facility.FacilityGeom.face's
  // numbering (0 = -z, 1 = +z, 2 = -x, 3 = +x)
  dir:Int,
  // and how many cells of it actually stand, AFTER the CASE_RUN_MAX clamp — so a face past the clamp
  // is free floor and free wall as far as anything reading this list is concerned
  len:Int,
};

// one rect of worktop a table cell actually occupies, plus the hand it was pulled back from (-1 for
// a cell that reaches every boundary). ONE of these for a plain or a thinned cell and TWO at an L
// corner, which is the whole reason this is a list — see `slabs`
typedef TableSlab = {
  x0:Float,
  x1:Float,
  z0:Float,
  z1:Float,
  hand:Int,
};

// the laboratory benches: the casework runs the generator lays beside every window wall, the island
// it puts in the middle of a room big enough to hold one, and — added here rather than by the
// generator — the shallow storage runs standing against the corridor walls (see `cabinets`).
//
// MERGED GEOMETRY and not a generated prop, which is the one decision worth recording here. A bench
// is a BOX — a worktop slab over a run of cabinet fronts — so the whole thing is six quads a cell
// against a glb's unwrap lottery, and it costs two draw calls for every bench in the area rather
// than one instanced batch per shape. What that buys is the part a prop cannot do: the generator
// deals 1x1, 1x3, 3x1, 2x3 and 3x2 blocks, and a run of instanced units would show a seam at every
// cell boundary, so a prop would have needed a shape per shape. Here the shapes are never named at
// all — a face is emitted toward a neighbour that is not a bench, exactly as the wall pass emits
// toward a neighbour that is not a wall, and every block the generator can lay falls out of it.
//
// what the 2D tile art shows is a plain slab with a thin front strip, so the silhouette is the whole
// job: the worktop overhangs the casework by FacilityStyle.BENCH_LIP and that shadow line is what
// stops a bench reading as a low wall. The overhang is taken out of the TOP, which is grown outward,
// and never out of the casework, which is pulled in — see BENCH_LIP for why that is a UV decision
//
// AND A BENCH GETS NO WALL HALO, which is the one place this family departs from every other thing
// that stands against masonry. It does not stand against it: a bench sits on its CELLS and
// FacilityGeom.slab insets a wall's room face a whole unit into the wall cell, so the nearest a
// worktop ever comes is 0.8 and its body 1.0 — 25 px of bare floor at the game camera between the
// shadow and the thing casting it, which reads as a stain on the wall rather than as contact. A
// contact shadow is for something TOUCHING. Sliding the block onto the wall to earn one was built and
// reverted (see docs/3d-changes.md); the fittings and the corridor casework keep theirs because both
// are built off the wall FACE and really do touch it.
//
// WHAT THE WORKTOP DOES GET is the shadow of the things standing ON it, which is the opposite case
// and the one the rule above argues FOR: a flask really does touch the resin it stands on. Those are
// 2D sprites and not geometry, so nothing here knows their size — see `build` and FacilityStyle
// .TABLE_POOL_R — but their CELLS are in the model, and a bench cell is already being walked
class FacilityTables
{
  static inline var CELL = CityConfig.CELL;
  // how close two worktop edges have to be to count as meeting. the slabs are built off CELL and
  // DESK_D alone, so a real coincidence is exact and this only guards the float compare
  static inline var EPS = 0.001;

  // the four cell-edge directions, in the order render.facility.FacilityGeom.face reads them:
  // 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// every bench in the area, in two merged meshes. returns how many CABINET cells the corridor pass
// added to them, which is the only number here a screenshot cannot give (see `cabinets`)
  public static function build(scene:Scene, m:Facility):Int
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var top = MeshBufTools.make();
      var body = MeshBufTools.make();
      // a desk is this same run in the office's own finish. the generator lays it with the SAME bench
      // tiles — the furniture is identical, a worktop over casework, and only the material differs —
      // so the split is two more buffers and no geometry at all (see FacilityStyle.DESK_TOP)
      var deskTop = MeshBufTools.make();
      var deskBody = MeshBufTools.make();
      // and the desk's END panels, which take the drawerless carcass side. a run's short faces are
      // not its drawer front, and one texture over all four was the same mistake FacilityStyle's
      // DECO_ block records for a bookcase wearing its own spines on its top
      var deskSide = MeshBufTools.make();
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!m.table[row][col])
              continue;
            var office = (m.surf[row][col] == Surf.OFFICE);
            var bTop = (office ? deskTop : top);
            var bBody = (office ? deskBody : body);
            // A DESK IS A THINNER BENCH, and it is the only geometry difference between the two. the
            // cell is shrunk on its OPEN side — the hand away from the wall the run backs onto — so
            // the carcass still meets the masonry and only the front edge comes forward less. every
            // rect below is taken off the slab, so the lip, the edge band, the casework and the
            // contact pool all follow with no further arithmetic.
            //
            // WHICH SIDE THAT IS, IF ANY, IS `slabs`'s AND NOT THIS LOOP's — three passes ask the
            // same oracle (FacilityClutter for how deep to roll its decals, FacilityWork.chairs for
            // how far out the seat goes), and a second copy of the rule is how a desk and the chair
            // at it end up disagreeing.
            //
            // AND IT IS A LIST, because an L CORNER IS AN L: the cell where two thinned runs meet
            // carries the front of both of them and neither one alone, so it is two rects and not one
            var cell = slabs(m, col, row);
            var plate = null;
            for (si in 0...cell.length)
              {
                var sl = cell[si];
                var open = sl.hand;
                var x0 = sl.x0, x1 = sl.x1;
                var z0 = sl.z0, z1 = sl.z1;
                // the contact pool takes the PLAIN cell and not the grown worktop: the field
                // darkens the floor the casework stands on, and the lip is an overhang a metre
                // above it
                ContactMask.prop(x0, x1, z0, z1);
                // the worktop, GROWN outward by BENCH_LIP on every side that does not carry on into
                // another bench cell — that overhang is the bench's silhouette, and taking it out
                // of the top rather than out of the casework is what keeps the cabinet fronts whole
                // (see FacilityStyle.BENCH_LIP). a side that continues reaches the plain boundary,
                // so abutting cells of one run still share a world-aligned grid and a 3-cell bench
                // is one unbroken sheet of resin.
                //
                // ONE SIDE GETS NO LIP: the one a door leaf swings past, because the leaf meets the
                // overhang edge-on (see `facesDoor`). The generator no longer lays a bench block
                // beside a doorway at all, so this only fires on areas that were already in a save
                // when that changed — the tiles are persisted and nothing migrates them
                //
                // AND "CARRIES ON" IS ASKED OF THE RECT, NOT OF THE CELL. An L corner's leg has a
                // bench cell in front of it — the other arm — and so took no lip, while the arm's
                // next cell along did: the two fronts stood BENCH_LIP apart and the edge band filled
                // the jog with a sliver, reported from the game as the corner not blending with
                // the desks. A side with any of its face exposed grows
                var ox0 = lipped(m, cell, si, col, row, 2) ? x0 - FacilityStyle.BENCH_LIP : x0;
                var ox1 = lipped(m, cell, si, col, row, 3) ? x1 + FacilityStyle.BENCH_LIP : x1;
                var oz0 = lipped(m, cell, si, col, row, 0) ? z0 - FacilityStyle.BENCH_LIP : z0;
                var oz1 = lipped(m, cell, si, col, row, 1) ? z1 + FacilityStyle.BENCH_LIP : z1;
                FacilityGeom.cap(bTop, ox0, ox1, oz0, oz1, FacilityStyle.BENCH_H,
                  FacilityStyle.BENCH_TOP_TILE);
                // and the round pool of shade under whatever the generator stood on this worktop —
                // FacilityDetail's own flat quad, the one it already lays under a box on a shelf
                // plate, because the compound's floor field cannot reach a surface two units up.
                //
                // `dz` IS NOT A NUDGE. The thing standing here is a BILLBOARD, and Sprites leans
                // every upright quad back by TILT about its own centre, so the icon's drawn base
                // lands well in FRONT of the cell it belongs to — up to half a unit. A pool on the
                // cell centre is a pool the object is standing clear of, and that is how the first
                // build was reported. `dx` is the other half of the same story and is NOT the tilt:
                // the art inside the cell is not centred on it, so the icon is drawn up to half a
                // unit off its own anchor. All three come off the icon's own alpha box, per frame,
                // which is why none of them is a number this file owns — see
                // FacilityModel.TableDeco.
                //
                // the PLATE is the GROWN rect and not the plain cell: the lip is real worktop, so a
                // decoration near the edge is allowed to cast onto it, and `pooled`'s per-side
                // clamp is what stops the gradient hanging off the front.
                //
                // an office desk never takes the laboratory sprite's pool: that decoration's icon
                // is suppressed (the glassware is the lab's) and the clutter standing in for it
                // carries its own shadow in the art. What it carries instead is the WORKSTATION's,
                // and that is three square quads rather than one round one — FacilityWork.pools
                // owns the footprints, because they are its objects' and not this file's
                //
                // ONE PLATE PER CELL and not per slab: what stands on a worktop is dealt to the
                // CELL, so an L corner's two rects share the first one's plate rather than laying a
                // second set
                if (plate == null)
                  plate = {
                    x0: ox0,
                    x1: ox1,
                    z0: oz0,
                    z1: oz1,
                  };
                // A HANGAR CONSOLE IS NOT AN OFFICE DESK AND CARRIES THE SAME THREE MACHINES.
                // FacilityWork.at lets the shed's console run in BY NAME — its cells are laid in
                // the laboratory's worktop tiles and are not an office by any surface — so gating
                // the pools on `office` left every workstation in the hangar standing on bare resin
                // with no contact shade at all, which is what a monitor floating over a worktop
                // looks like. Asked of `at` instead, i.e. of the same oracle the geometry and the
                // clutter both ask, so the three passes cannot disagree about which cells carry a
                // set
                if (si == 0)
                  {
                    if (office ||
                        FacilityWork.at(m, col, row) != null)
                      FacilityWork.pools(m, col, row, plate);
                    else
                      {
                        var td = m.tableDeco[row][col];
                        if (td != null)
                          FacilityDetail.deck({
                            cx: (col + 0.5) * CELL - half + td.dx,
                            cz: (row + 0.5) * CELL - half + td.dz,
                            hw: td.r,
                            hd: td.r,
                            yaw: 0.0,
                            y: FacilityStyle.BENCH_H,
                            plate: plate,
                          });
                      }
                  }
                for (dir in 0...4)
                  {
                    // TWO DESKS MEETING AT A ROOM CORNER abut over PART of the boundary they share,
                    // and a boolean `closes` could never say which part: `wallHand` takes the FIRST
                    // wall it finds, so a corner cell and its neighbour are thinned on DIFFERENT
                    // axes and the neighbour reaches DESK_D of the shared boundary and no more.
                    // `exposed` subtracts whatever really meets this face — the neighbour cell's
                    // rects and, at an L corner, this cell's own other rect — and emits the strips
                    // left over. A face fully met emits nothing, which is the whole of what
                    // `closes` used to answer
                    for (e in exposed(m, cell, si, col, row, dir))
                      {
                        // back out to the GROWN rect at an end that is still the slab's own end:
                        // the lip is the bench's silhouette and only an outer edge has one
                        var alongX = (dir < 2);
                        var p0 = (alongX ? x0 : z0);
                        var p1 = (alongX ? x1 : z1);
                        var g0 = (e.a <= p0 + EPS ? (alongX ? ox0 : oz0) : e.a);
                        var g1 = (e.b >= p1 - EPS ? (alongX ? ox1 : oz1) : e.b);
                        // the worktop's edge band, out on the grown rect with it
                        FacilityGeom.face(bTop,
                          (alongX ? g0 : ox0), (alongX ? g1 : ox1),
                          (alongX ? oz0 : g0), (alongX ? oz1 : g1), dir,
                          FacilityStyle.BENCH_H - FacilityStyle.BENCH_EDGE, FacilityStyle.BENCH_H,
                          FacilityStyle.BENCH_TOP_TILE);
                        // and the casework on the plain rect, so u keeps the world phase and the
                        // door rhythm lands whole. an office desk's two END faces — the ones on the
                        // axis the run travels along — take the drawerless side instead
                        var end = (office && open >= 0 && (dir < 2) != (open < 2));
                        panel(end ? deskSide : bBody,
                          (alongX ? e.a : x0), (alongX ? e.b : x1),
                          (alongX ? z0 : e.a), (alongX ? z1 : e.b), dir);
                      }
                  }
              }
          }
      // no soffit under the overhang and no floor under the casework. the ring left open at the top
      // of the body is BENCH_LIP wide and sits behind the edge band from anything above it: at the
      // camera's 51 degrees a ray entering at the bottom of the band drops 0.25 units over the 0.2
      // it travels inward and lands on the cabinet face, so there is nothing to see through.
      //
      // at a CONCAVE corner — where one run meets another and the block is not a rectangle — the two
      // grown rects overlap by BENCH_LIP squared. The caps are coplanar, same texture, same
      // world-aligned UVs, so that overlap resolves to the same pixel either way; the two edge bands
      // cross, each poking BENCH_LIP past the other, which is 0.2 world units and reads as nothing
      var n = cabinets(m, top, body);
      add(scene, top, FacilityStyle.BENCH_TOP);
      add(scene, body, FacilityStyle.BENCH_BODY);
      add(scene, deskTop, FacilityStyle.DESK_TOP);
      add(scene, deskBody, FacilityStyle.DESK_BODY);
      add(scene, deskSide, FacilityStyle.DESK_SIDE);
      return n;
    }

// which side of this table cell the run backs onto, or -1 for a free-standing one.
//
// a desk is laid under the GLAZING, so the hand it stands against is usually a window and the test is
// isWall and not isSolidWall — a desk is against whatever the desk is against. PUBLIC because
// render.facility.FacilityWork needs the same answer to face a screen the right way, and two copies
// of a wall search is exactly how a desk and the thing standing on it end up disagreeing
  public static function wallHand(m:Facility, col:Int, row:Int):Int
    {
      for (d in 0...4)
        if (FacilityModel.isWall(m, col + DC[d], row + DR[d]))
          return d;
      return -1;
    }

// which hand this cell's worktop was pulled BACK from, or -1 for one that reaches every boundary.
// a thinned run is pulled back on the hand away from the wall it stands against, and on no other.
//
// THE HANGAR'S CONSOLE IS THINNED TOO, which it was not: a console is a desk somebody sits at, and a
// worktop filling its 4.0 cell put the chair FacilityWork.chairs stands in front of it 1.33 units
// into the next cell — the middle of a walkable one, drawn through the player standing there, which
// is what was reported. Thinned, the seat lands 1.93 out like every office desk's, i.e. inside the
// desk's own cell. The material does not follow: the shed's run keeps the laboratory bench finish it
// is laid in, because only its DEPTH was wrong.
//
// AND A RUN THAT CARRIES ON HAS NO FRONT TO PULL BACK. `wallHand` takes the first wall it finds, so
// the corner cell of an L backs onto one wall and its neighbour onto the other; each was then cut
// DESK_D on its own axis and the two stood 1.4 apart with a slot of floor between them, reported
// from the game as a weird corner. The same cut opens the same slot down the middle of the 2x3 block
// the generator also deals. A cell with another bench on its open side is not cut at all, so the
// corner fills and the L is one piece
  public static function openHand(m:Facility, col:Int, row:Int):Int
    {
      var h = openHands(m, col, row);
      return (h.length == 0 ? -1 : h[0]);
    }

// EVERY hand this cell is pulled back from — none, one, or the TWO of an L corner.
//
// an L CORNER IS AN L AND WAS A SQUARE. The cell where two thinned runs meet backs onto two
// perpendicular walls and carries a bench on both open sides, so the single-hand rule above refused
// to cut it at all and it stood as a full 4.0 square while both arms came forward only DESK_D —
// measured 1.4 x 1.4 of worktop past the front of both of them, reported from the game. Cutting it
// on ONE hand is the fault the rule was written against (a 1.4 slot of bare floor between the two
// runs), so the answer is neither: it is cut on BOTH, and `slabs` puts the piece that joins the two
// arms back as a second rect.
//
// A RUN THAT CARRIES ON STILL HAS NO FRONT TO PULL BACK. One wall and a bench on its open side is
// the 2x3 block the generator also deals, and cutting that opens the same slot down its middle — so
// the pair is taken only where a SECOND, perpendicular wall says this really is a corner
  public static function openHands(m:Facility, col:Int, row:Int):Array<Int>
    {
      if (!FacilityModel.isTable(m, col, row) ||
          (m.surf[row][col] != Surf.OFFICE &&
           !FacilityModel.inHangar(m, col, row)))
        return [];
      var h = wallHand(m, col, row);
      if (h < 0)
        return [];
      var o = h ^ 1;
      if (!FacilityModel.isTable(m, col + DC[o], row + DR[o]))
        return [o];
      // the open side carries another bench. the only cut still on the table is the L's
      for (d in 0...4)
        {
          if ((d < 2) == (h < 2) ||
              !FacilityModel.isWall(m, col + DC[d], row + DR[d]))
            continue;
          var o2 = d ^ 1;
          if (FacilityModel.isTable(m, col + DC[o2], row + DR[o2]))
            return [o, o2];
        }
      return [];
    }

// the rects of worktop this cell actually occupies. one for a plain or a thinned cell; at an L
// corner TWO, whose union is the L: the leg pulled back from the first hand, plus the stub that
// fills the strip it gave up as far as the second hand's own cut
  public static function slabs(m:Facility, col:Int, row:Int):Array<TableSlab>
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      var hands = openHands(m, col, row);
      var base:TableSlab = {
        x0: x0,
        x1: x0 + CELL,
        z0: z0,
        z1: z0 + CELL,
        hand: (hands.length == 0 ? -1 : hands[0]),
      };
      if (hands.length == 0)
        return [base];
      var cut = CELL - FacilityStyle.DESK_D;
      if (hands.length == 1)
        return [pull(base, hands[0], cut)];
      // the strip the first cut gives up, itself cut on the second hand: what joins the two arms
      var stub = pull(base, hands[0] ^ 1, CELL - cut);
      stub.hand = hands[1];
      return [pull(base, hands[0], cut), pull(stub, hands[1], cut)];
    }

// one rect pulled back `d` on the given hand
  static function pull(s:TableSlab, hand:Int, d:Float):TableSlab
    {
      return {
        x0: (hand == 2 ? s.x0 + d : s.x0),
        x1: (hand == 3 ? s.x1 - d : s.x1),
        z0: (hand == 0 ? s.z0 + d : s.z0),
        z1: (hand == 1 ? s.z1 - d : s.z1),
        hand: s.hand,
      };
    }

// does slab `si` overhang on its `dir` side? yes wherever any of that face is exposed, except the
// side a door leaf swings past
  static function lipped(m:Facility, cell:Array<TableSlab>, si:Int, col:Int, row:Int,
      dir:Int):Bool
    {
      return (!facesDoor(m, col, row, dir) &&
        exposed(m, cell, si, col, row, dir).length > 0);
    }

// the spans of slab `si`'s `dir` face that nothing meets, along that face's own free axis.
//
// a full cell's neighbour covers the whole of it and nothing is emitted; a neighbour thinned on the
// other axis covers DESK_D of it and the rest is a hole straight into this cell's carcass; and at an
// L corner this cell's OWN other rect covers part of one face. All three are the same subtraction,
// which is why the boolean `closes` this replaced could not answer the middle one
  static function exposed(m:Facility, cell:Array<TableSlab>, si:Int, col:Int, row:Int,
      dir:Int):Array<{ a:Float, b:Float }>
    {
      var s = cell[si];
      var alongX = (dir < 2);
      var a0 = (alongX ? s.x0 : s.z0);
      var a1 = (alongX ? s.x1 : s.z1);
      var plane = switch (dir)
        {
          case 0: s.z0;
          case 1: s.z1;
          case 2: s.x0;
          default: s.x1;
        };
      // whatever can reach this face: the neighbour cell's rects, and our own sibling at a corner
      var near = FacilityModel.isTable(m, col + DC[dir], row + DR[dir])
        ? slabs(m, col + DC[dir], row + DR[dir]) : [];
      var blocks = [];
      for (i in 0...(near.length + cell.length))
        {
          var t = (i < near.length ? near[i] : cell[i - near.length]);
          if (i >= near.length &&
              i - near.length == si)
            continue;
          // its OWN face on this plane is the opposite one, so the test is mirrored
          var tp = switch (dir)
            {
              case 0: t.z1;
              case 1: t.z0;
              case 2: t.x1;
              default: t.x0;
            };
          if (Math.abs(tp - plane) > EPS)
            continue;
          var b0 = (alongX ? t.x0 : t.z0);
          var b1 = (alongX ? t.x1 : t.z1);
          if (b1 > a0 + EPS &&
              b0 < a1 - EPS)
            blocks.push({ a: b0, b: b1 });
        }
      blocks.sort(function(p, q) return p.a < q.a ? -1 : (p.a > q.a ? 1 : 0));
      var out = [];
      var cur = a0;
      for (bl in blocks)
        {
          if (bl.a > cur + EPS)
            out.push({ a: cur, b: (bl.a < a1 ? bl.a : a1) });
          if (bl.b > cur)
            cur = bl.b;
        }
      if (cur < a1 - EPS)
        out.push({ a: cur, b: a1 });
      return out;
    }

// does a door opening lie past this cell's `dir` face — straight through it, or diagonally past
// either of its corners?
//
// a leaf hinges ON the cell boundary and swings a quarter turn through its OWN cell, so the quadrant
// it sweeps is the quarter of the door cell nearest whatever stands beside it. A worktop lip grown
// that way is met edge-on by the swing: measured on the compound's one such bench, the leaf's last
// 0.2 units ended up inside the worktop and the whole quarter disc crossed its corner.
//
// the same DIAGONAL reach FacilityModel.nearDoor takes, narrowed to ONE face — a bench beside a
// doorway keeps its overhang on the other three sides, where the silhouette is the point of it
  static function facesDoor(m:Facility, col:Int, row:Int, dir:Int):Bool
    {
      var c = col + DC[dir];
      var r = row + DR[dir];
      var pc = (dir < 2 ? 1 : 0);
      var pr = (dir < 2 ? 0 : 1);
      return FacilityModel.isDoor(m, c, r) ||
        FacilityModel.isDoor(m, c - pc, r - pr) ||
        FacilityModel.isDoor(m, c + pc, r + pr);
    }

// hand one run of CORRIDOR CASEWORK to the wall behind it. benches do not come through here — a
// bench sits on its cells and never touches its wall, so it gets no halo at all (see the header).
//
// the span is the run's own CELLS and the clamp to the masonry is the emitter's — a cabinet is
// already slab-clamped along the wall, and letting FacilityDetail cut it keeps the rule that a halo
// never hangs off the end of a wall in one place.
//
// `y` is a literal 0 and NOT FacilityGround.surfY, because 0 is where this file actually builds:
// `panel` emits from it and `cap` sits at BENCH_H over it, so the halo has to stand on the plane the
// geometry is on rather than on the one the surface grid would name
  static function halo(col:Int, row:Int, dir:Int, len:Int):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var a0 = (dir < 2 ? col : row) * CELL - half;
      FacilityDetail.stand({
        col: col,
        row: row,
        dir: dir,
        a0: a0,
        a1: a0 + len * CELL,
        len: len,
        y: 0.0,
        h: FacilityStyle.BENCH_H,
      });
    }

// every corridor casework RUN the compound stands: the run's first cell, the wall it is bolted to
// and how many cells of it actually stand after the CASE_RUN_MAX clamp.
//
// RUNS AND NOT CELLS. the gate is rolled once per run and the whole run stands or does not: gating
// per cell turns a wall into a dotted line of isolated boxes, which reads as dropped junk rather than
// as fitted casework. a run is claimed as it is walked, so the outer scan never restarts inside one.
//
// PUBLIC AND RECOMPUTED RATHER THAN RECORDED, which is what lets render.facility.FacilityPoint keep a
// wall fitting off a cabinet with no ordering between the two builders: this is a pure function of
// the saved grid, so asking it twice cannot give two answers. Exactly the discipline `hugs` and
// FacilityGround.bins already keep between the casework and the litter bins
  public static function runs(m:Facility):Array<CaseRun>
    {
      var seen = new Map<Int, Bool>();
      var out = [];
      for (dir in 0...4)
        {
          // a run follows the WALL, so it advances along x for a wall in z and along z for one in x
          var sc = (dir < 2 ? 1 : 0);
          var sr = (dir < 2 ? 0 : 1);
          for (row in 0...m.h)
            for (col in 0...m.w)
              {
                if (seen.exists(key(m, col, row, dir)) ||
                    !hugs(m, col, row, dir))
                  continue;
                // walk to the run's end, claiming every cell on the way
                var len = 0;
                while (hugs(m, col + sc * len, row + sr * len, dir))
                  {
                    seen.set(key(m, col + sc * len, row + sr * len, dir), true);
                    len++;
                  }
                if (len < FacilityStyle.CASE_RUN_MIN)
                  continue;
                var h = FacilityModel.mix((col * 374761393) ^ (row * 668265263) ^ (dir * 83492791));
                if (h % 1000 >= FacilityStyle.CASE_PCT * 1000)
                  continue;
                out.push({
                  col: col,
                  row: row,
                  dir: dir,
                  len: (len > FacilityStyle.CASE_RUN_MAX ? FacilityStyle.CASE_RUN_MAX : len),
                });
              }
        }
      return out;
    }

// the storage casework standing against the corridor walls, merged into the SAME two buffers the
// benches are — so a corridor full of it costs no draw call and no art at all.
//
// the generator furnishes ROOMS and nothing else: it lays a run of benches under every window wall
// and drops an island in a room big enough, and a corridor comes out of it as bare lino between two
// bare walls. this is the corridor's half of that, and it is not a bench — a bench is a whole cell
// deep and the tiles say so, while these are render-only and CASE_D shallow, which is what lets them
// stand in the one place the player actually walks (see FacilityStyle.CASE_D)
  static function cabinets(m:Facility, top:MeshBuf, body:MeshBuf):Int
    {
      var n = 0;
      for (r in runs(m))
        {
          var sc = (r.dir < 2 ? 1 : 0);
          var sr = (r.dir < 2 ? 0 : 1);
          for (i in 0...r.len)
            {
              unit(top, body, m, r.col + sc * i, r.row + sr * i, r.dir, i == 0, i == r.len - 1);
              n++;
            }
          // and ONE halo for the whole run on the masonry behind it — see
          // render.facility.FacilityDetail.halos. per RUN and never per cell: the quads are
          // transparent with depthWrite off, so two of them overlapping along one wall blend
          // through each other and stack to a hard band, which is the seam the corner strips
          // shipped with once
          halo(r.col, r.row, r.dir, r.len);
        }
      return n;
    }

// one cell's slot in the claimed-cell set. a cell is claimed PER DIRECTION and not outright: a
// corridor two cells wide has a wall on either hand, and a cell already standing a run against its
// north wall is still a candidate for the one against its south
  static inline function key(m:Facility, col:Int, row:Int, dir:Int):Int
    {
      return ((dir * m.h + row) * m.w) + col;
    }

// may a cabinet stand on this corridor cell, against the wall in `dir`?
//
// the CORNER exclusion is what divides this pass from the litter bins, which take exactly the cells
// this rejects (FacilityGround.bins). Both derive the same predicate off the model rather than
// sharing a list, so neither has to run before the other and neither can drop a bin inside a cabinet.
//
// public because render.facility.FacilityPoint stands its wall fittings on the same predicate, and
// gets the bin exclusion for free by doing so: the corner cells this rejects are the bins' cells
  public static function hugs(m:Facility, col:Int, row:Int, dir:Int):Bool
    {
      if (!FacilityModel.inside(m, col, row) ||
          m.surf[row][col] != Surf.LINO ||
          !FacilityModel.isSolidWall(m, col + DC[dir], row + DR[dir]))
        return false;
      // a cell with walls on two PERPENDICULAR hands is a dead end or an inside corner, and that is
      // the bin's cell
      if ((FacilityModel.isSolidWall(m, col, row - 1) ||
           FacilityModel.isSolidWall(m, col, row + 1)) &&
          (FacilityModel.isSolidWall(m, col - 1, row) ||
           FacilityModel.isSolidWall(m, col + 1, row)))
        return false;
      return !FacilityModel.nearDoor(m, col, row);
    }

// one cabinet cell: the worktop cap, and an edge band plus a cabinet front on every side that is not
// the wall behind it and not the next cabinet of its own run.
//
// the rect is taken off the WALL FACE and not off the cell boundary — FacilityGeom.slab insets a
// straight run by a unit, so a cabinet built on the cell edge would float a unit clear of its own
// wall. the worktop is grown by BENCH_LIP on the open sides exactly as a bench's is, and NEVER on the
// wall side, where the overhang would poke into the masonry
  static function unit(top:MeshBuf, body:MeshBuf, m:Facility, col:Int, row:Int, dir:Int,
      first:Bool, last:Bool):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
      var x0 = col * CELL - half, x1 = x0 + CELL;
      var z0 = row * CELL - half, z1 = z0 + CELL;
      // ALONG the wall the unit takes the MASONRY's extent and not the cell's. slab() insets a side
      // by (CELL - WALL_T) / 2 wherever the wall line stops there, so the last cell of a run shows
      // 3 units of face in a 4-unit cell — and a unit built on the cell boundary hung a whole unit
      // past the end of the wall it is bolted to. across the wall it is already the slab's, which is
      // where CASE_D is measured from
      if (dir < 2)
        {
          x0 = Math.max(x0, s.x0);
          x1 = Math.min(x1, s.x1);
        }
      else
        {
          z0 = Math.max(z0, s.z0);
          z1 = Math.min(z1, s.z1);
        }
      switch (dir)
        {
          case 0:
            z0 = s.z1;
            z1 = s.z1 + FacilityStyle.CASE_D;
          case 1:
            z1 = s.z0;
            z0 = s.z0 - FacilityStyle.CASE_D;
          case 2:
            x0 = s.x1;
            x1 = s.x1 + FacilityStyle.CASE_D;
          default:
            x1 = s.x0;
            x0 = s.x0 - FacilityStyle.CASE_D;
        }
      // and the same plain body rect the benches hand over — after the slab clamp and the CASE_D
      // depth, before the lip grows the worktop out over it
      ContactMask.prop(x0, x1, z0, z1);
      // the grown worktop: out over the front always, and over an end only where the run stops
      var lip = FacilityStyle.BENCH_LIP;
      var ox0 = x0, ox1 = x1, oz0 = z0, oz1 = z1;
      if (dir == 0)
        oz1 += lip;
      else if (dir == 1)
        oz0 -= lip;
      else if (dir == 2)
        ox1 += lip;
      else
        ox0 -= lip;
      if (dir < 2)
        {
          if (first)
            ox0 -= lip;
          if (last)
            ox1 += lip;
        }
      else
        {
          if (first)
            oz0 -= lip;
          if (last)
            oz1 += lip;
        }
      FacilityGeom.cap(top, ox0, ox1, oz0, oz1, FacilityStyle.BENCH_H, FacilityStyle.BENCH_TOP_TILE);
      // the run's two ends, in the direction numbering: the axis the wall does NOT lie on
      var head = (dir < 2 ? 2 : 0);
      for (d in 0...4)
        {
          // the wall side is closed, the front is always open — dir ^ 1 is the opposite hand of the
          // same axis — and an end is open only where this cabinet is the run's first or last
          var open = (d == (dir ^ 1)) ||
            (d == head && first) ||
            (d == head + 1 && last);
          if (!open)
            continue;
          FacilityGeom.face(top, ox0, ox1, oz0, oz1, d,
            FacilityStyle.BENCH_H - FacilityStyle.BENCH_EDGE, FacilityStyle.BENCH_H,
            FacilityStyle.BENCH_TOP_TILE);
          panel(body, x0, x1, z0, z1, d);
        }
    }

// one cabinet-front quad.
//
// the same winding FacilityGeom.face uses, through the same `ends`, but with a DIFFERENT PERIOD ON
// EACH AXIS — which is the whole reason this is not a call to `face`. `u` has to be world-aligned on
// FacilityStyle.BENCH_TILE so a door lands on the cell grid and a run never ends on half of one,
// while `v` has to run 0..1 over the body's own height so the art's bottom-up composition lands
// whole. One `t` cannot do both, and `face` has one `t`
  static function panel(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      var us = (dir < 2 ? e[0] : e[1]) / FacilityStyle.BENCH_TILE;
      var ue = (dir < 2 ? e[2] : e[3]) / FacilityStyle.BENCH_TILE;
      var y1 = FacilityStyle.BENCH_H - FacilityStyle.BENCH_EDGE;
      MeshBufTools.quad(b, [e[0], 0, e[1]], [e[2], 0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [us, 0, ue, 0, ue, 1, us, 1]);
    }

// the height of whatever an actor or a decal rests on at a WORLD point, for render.world.WorldCtx
// .ground. two things stack here and neither is optional.
//
// the WORKTOP is what stands a table decoration ON its bench instead of inside it: the generator
// writes the decoration onto the SAME cell as the table tile it belongs to (FacilityAreaGenerator's
// chem-lab pass), so without this every flask and microscope in the area sits at y = 0 with a metre
// of casework in front of it.
//
// the SURFACE is the kerb step (FacilityStyle.KERB_DROP), and routing it through here is what makes
// the whole compound follow for free — actors, decals, the slime trail, the path line, the tactical
// grid and the cursor pick all read this one hook and nothing else had to be touched
  public static function groundY(m:Facility, x:Float, z:Float):Float
    {
      var c = CityConfig.worldToCell(x, z);
      if (FacilityModel.isTable(m, c.col, c.row))
        return FacilityStyle.BENCH_H;
      if (!FacilityModel.inside(m, c.col, c.row))
        return 0.0;
      return FacilityGround.surfY(m.surf[c.row][c.col]);
    }

// merge one buffer into a lit mesh. interior surfaces, so they receive the moon's shadow and cast
// none of their own — the same pair every indoor buffer in FacilityGeom takes
  static function add(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      var mesh = new Mesh(geo, VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: THREE.FrontSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
