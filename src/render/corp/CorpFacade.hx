package render.corp;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityGeom.Notch;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityStyle;
import render.world.DowntownStyle;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// the nineteen storeys UNDER the floor plate, and the soffit that closes it from below.
//
// THIS IS WHAT MAKES IT THE TWENTIETH FLOOR. Up to here a corp area was a floor plate sitting in
// the dark with a parapet round it: walk to the edge, look over, and there is nothing — no tower,
// and the plate's own underside open to the sky. Two merged meshes fix both, and neither costs a
// per-frame anything.
//
// UNLIT, WHICH IS THE ONE DECISION IN THE FILE. The cladding is a MeshBasicMaterial and not the
// lambert every other shell surface here uses, because the plate's lighting rig has nothing to do
// with a wall 114 units below it: under the scene's ambient a lambert takes the art's window bays
// to nothing, which is the whole read gone. Unlit means the AUTHORED value is the RENDERED value.
// The LIT BAYS scattered over it are the one exception and have to be — a bloom is driven off an
// emissive term — and they take exactly the material the street's own lit panes take, because the
// tower IS one of those towers seen from the inside (CorpStyle.FACADE_SLOT).
//
// AND NO VISION MASK ON EITHER, unlike everything on the plate: the mask's rim channel sinks a
// surface to the fog colour at the area border, and the border IS the tower's edge. Patched, the
// facade would be cut to nothing exactly where the player leans over the parapet to see it. It is
// outside the building in the sense the mask means, so it is simply never patched — the same rule
// the street below it follows.
class CorpFacade
{
  static inline var CELL = CityConfig.CELL;

  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// the tower below and the soffit under the plate. returns the quad counts, for __corp()
  public static function build(scene:Scene, m:Facility):{ clad:Int, soffit:Int, lit:Int }
    {
      var clad = MeshBufTools.make();
      var shaft = MeshBufTools.make();
      var soff = MeshBufTools.make();
      var lit = MeshBufTools.make();
      var st = DowntownStyle.get();
      var half = (CityConfig.GRID * CELL) / 2;
      var nLit = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            // the SOFFIT covers every cell of the building, masonry and floor alike: the underside
            // of a floor plate is one continuous slab and the walls stand on it. Per cell and not
            // one rect over the whole footprint, because a plate is not guaranteed rectangular —
            // the generator draws rings today and a flood fill that ever merged two footprints
            // would leave an L, and one rect over an L is a soffit hanging in the air
            var inb = FacilityModel.isIndoor(m, col, row) ||
              FacilityGeom.carries(m, col, row);
            if (!inb)
              continue;
            var x0 = col * CELL - half;
            var z0 = row * CELL - half;
            // and it is cut back by PARAPET_INSET on exactly the hands the cladding DROPS on,
            // which is not tidiness: the drop stands that far inside the cell, so a soffit on the
            // full cell rect oversails it by a whole unit with nothing closing the overhang — a
            // lip of ceiling hanging in the air right where the player leans over to look down.
            // The test is `outward` and NOT the ring rect, which insets wherever the wall line
            // stops — including on the INWARD hand, where it would open a unit-wide slot between
            // this soffit and the room's next door
            var e = FacilityStyle.PARAPET_INSET;
            FacilityGeom.capDown(soff,
              x0 + (FacilityGeom.outward(m, col, row, 2) ? e : 0.0),
              x0 + CELL - (FacilityGeom.outward(m, col, row, 3) ? e : 0.0),
              z0 + (FacilityGeom.outward(m, col, row, 0) ? e : 0.0),
              z0 + CELL - (FacilityGeom.outward(m, col, row, 1) ? e : 0.0),
              CorpStyle.SOFFIT_Y, FacilityStyle.WALL_TILE);
            var s = ring(m, col, row, half);
            if (!FacilityGeom.carries(m, col, row))
              continue;
            // the CLADDING drops off every outward face of the perimeter. `ring` is the parapet's
            // own plane and not the cell's masonry slab, for the parapet's own reason: a glazed
            // cell's slab is GLASS_T where its neighbours' are WALL_T, so a facade following the
            // slab would jog half a unit in and out at every window run's two ends. Taking the
            // ring plane puts the drop dead flush with the parapet band 6 units over it
            var sl = FacilityGeom.slab(m, col, row);
            var lift = liftAt(m, col, row);
            for (dir in 0...4)
              {
                if (!FacilityGeom.outward(m, col, row, dir))
                  continue;
                var alongX = (dir < 2);
                var p = alongX ? (dir == 0 ? s.z0 : s.z1) : (dir == 2 ? s.x0 : s.x1);
                if (lift)
                  FacilityGeom.face(shaft, alongX ? s.x0 : p, alongX ? s.x1 : p,
                    alongX ? p : s.z0, alongX ? p : s.z1, dir, CorpStyle.STREET_Y,
                    FacilityStyle.WALL_BASE, CorpStyle.SHAFT_TILE);
                else if (alongX)
                  drop(clad, lit, st, col, row, dir, s.x0, s.x1, p, p);
                else
                  drop(clad, lit, st, col, row, dir, p, p, s.z0, s.z1);
                // AND THE LEDGE BETWEEN THE TWO PLANES, which is the hole reported at the window
                // line. A GLAZED cell's slab insets by GLASS_T's half (1.5) where the ring plane
                // this drop stands on insets by PARAPET_INSET (1.0), so the glass wall above sits
                // half a unit further in than the cladding below it and nothing closes the step —
                // an open 0.5-wide slot at y = WALL_BASE running the whole length of every window
                // run, with the void under the plate visible through it. render.facility
                // .FacilityGeom.band caps the identical step at the parapet with its `soffit`
                // quad; this is that quad, the other way up. A SOLID cell's two insets are equal,
                // so the rect comes out zero-wide and `cap` drops it.
                //
                // IN THE CAPPING AND NOT THE CURTAIN WALL. It wore the cladding's art, which laid a
                // 0.5-deep slice of a window flat on a sill with no window under it — no mapping
                // fixes that. It is the aluminium the plate's wall and window heads wear (the
                // soffit's own buffer, so no draw and no layer of its own). The lift's steel is a
                // frame and folds over the edge, see `ledge`
                var r:Rect = {
                  x0: dir == 3 ? sl.x1 : s.x0,
                  x1: dir == 2 ? sl.x0 : s.x1,
                  z0: dir == 1 ? sl.z1 : s.z0,
                  z1: dir == 0 ? sl.z0 : s.z1,
                };
                if (lift)
                  ledge(shaft, r, dir, p);
                else
                  FacilityGeom.cap(soff, r.x0, r.x1, r.z0, r.z1, FacilityStyle.WALL_BASE,
                    FacilityStyle.WALL_TILE);
              }
            // AND THE REENTRANT CORNERS, which are a 1 x 1 SLOT 114 UNITS TALL without this.
            //
            // At a step in the footprint the two outward faces belong to DIFFERENT cells and
            // neither covers the corner square between them — reported from the game as a hole
            // between two faces of the drop, and measured on a live tower at the lift core, whose
            // 3x3 car stands outside the wall ring and so puts four reentrant corners in a plate
            // whose ring is otherwise a rectangle. render.facility.FacilityGeom.parapet has
            // carried this exact loop since it was written; the drop under it did not
            for (n in notches(m, col, row, half))
              {
                if (FacilityModel.isIndoor(m, n.col, n.row))
                  continue;
                // a notch is PARAPET_INSET wide, under a window's width, so it never carries a bay
                if (lift)
                  {
                    FacilityGeom.face(shaft, n.dx == 3 ? n.x0 : n.x1, n.dx == 3 ? n.x0 : n.x1,
                      n.z0, n.z1, n.dx, CorpStyle.STREET_Y, FacilityStyle.WALL_BASE,
                      CorpStyle.SHAFT_TILE);
                    FacilityGeom.face(shaft, n.x0, n.x1, n.dz == 1 ? n.z0 : n.z1,
                      n.dz == 1 ? n.z0 : n.z1, n.dz, CorpStyle.STREET_Y, FacilityStyle.WALL_BASE,
                      CorpStyle.SHAFT_TILE);
                    continue;
                  }
                drop(clad, lit, st, col, row, n.dx,
                  n.dx == 3 ? n.x0 : n.x1, n.dx == 3 ? n.x0 : n.x1, n.z0, n.z1);
                drop(clad, lit, st, col, row, n.dz,
                  n.x0, n.x1, n.dz == 1 ? n.z0 : n.z1, n.dz == 1 ? n.z0 : n.z1);
              }
          }
      nLit = Std.int(lit.idx.length / 6);
      add(scene, clad, st.walls[CorpStyle.FACADE_SLOT]);
      add(scene, shaft, CorpStyle.SHAFT);
      add(scene, soff, CorpStyle.CAP);
      CorpStreet.addLit(scene, lit, st, CorpStyle.FACADE_SLOT);
      return {
        clad: Std.int(clad.idx.length / 6),
        soffit: Std.int(soff.idx.length / 6),
        lit: nLit,
      };
    }

// one length of cladding, from the street up to the plate's own wall base, plus whichever of its
// bays are lit.
//
// IT STOPS AT WALL_BASE AND NOT AT 0. The plate's exterior wall is emitted on the slab plane from
// WALL_BASE (-KERB_DROP) up, and for a SOLID cell the slab's inset is PARAPET_INSET exactly — so a
// drop running to 0 is coplanar with it over that 0.2 and z-fights in a band all the way round the
// building. A glazed cell's slab is half a unit further in and hides it, which is why it showed as
// a flicker on some elevations and not others
  static function drop(clad:MeshBuf, lit:MeshBuf, st:render.world.AreaStyle, col:Int, row:Int,
      dir:Int, x0:Float, x1:Float, z0:Float, z1:Float):Void
    {
      FacilityGeom.face(clad, x0, x1, z0, z1, dir, CorpStyle.STREET_Y, FacilityStyle.WALL_BASE,
        CorpStyle.FACADE_TILE);
      if (st.glassAccentLit == null ||
          st.glassAccentLit[CorpStyle.FACADE_SLOT] == null)
        return;
      // the bays, on the same CELL grid the art tiles at and off the same hash render.world
      // .Windows picks a lit pane with — so the tower's own lit windows and the street towers'
      // are one population and cannot drift apart
      //
      // ON THE CLADDING'S OWN WINDOW GRID, i.e. at world multiples of CELL, since `face` maps it at
      // world coord / FACADE_TILE: only the whole windows inside this run and between the street and
      // the wall base. Counted off the run's corner and the street instead, every bay sat half a
      // window low (STREET_Y is -28.5 windows) and a corner cell's ran past the corner
      var alongX = (dir < 2);
      var lo = (alongX ? x0 : z0);
      var hi = (alongX ? x1 : z1);
      var i0 = Math.ceil(lo / CELL - 0.001);
      var n = Math.floor(hi / CELL + 0.001) - i0;
      var j0 = Math.ceil(CorpStyle.STREET_Y / CELL - 0.001);
      var rows = Math.floor(FacilityStyle.WALL_BASE / CELL + 0.001) - j0;
      for (i in 0...n)
        for (j in 0...rows)
          {
            var hv = (col * 92837111) ^ (row * 689287499) ^ (dir * 283923481) ^
              (i * 374761393) ^ (j * 668265263);
            hv = hv ^ (hv >>> 15);
            if ((hv & 0xffff) / 65536 >= st.glassLitRatio)
              continue;
            var a = (i0 + i) * CELL;
            var e = CorpStyle.LIT_PROUD;
            var px0 = alongX ? a : (dir == 2 ? x0 - e : x0 + e);
            var pz0 = alongX ? (dir == 0 ? z0 - e : z0 + e) : a;
            FacilityGeom.pane(lit,
              alongX ? a : px0, alongX ? a + CELL : px0,
              alongX ? pz0 : a, alongX ? pz0 : a + CELL,
              dir, (j0 + j) * CELL, (j0 + j + 1) * CELL);
          }
    }

// one lift-cell ledge, the shaft art FOLDED over the drop's top edge: u runs along the run exactly as
// `face` maps it, and v carries on up from WALL_BASE by the distance in from the outer plane `p`, so
// the steel turns the corner. FacilityGeom.cap maps by world x/z at whatever tile it is handed, which
// put this at FACADE_TILE against the shaft's SHAFT_TILE and the run in v on the two z hands
  static function ledge(b:MeshBuf, r:Rect, dir:Int, p:Float):Void
    {
      if (r.x1 - r.x0 < 0.01 ||
          r.z1 - r.z0 < 0.01)
        return;
      var t = CorpStyle.SHAFT_TILE;
      var y = FacilityStyle.WALL_BASE;
      var alongX = (dir < 2);
      inline function u(x:Float, z:Float):Float
        return (alongX ? x : z) / t;
      inline function v(x:Float, z:Float):Float
        return (y + Math.abs((alongX ? z : x) - p)) / t;
      MeshBufTools.quad(b, [r.x0, y, r.z1], [r.x1, y, r.z1], [r.x1, y, r.z0], [r.x0, y, r.z0], [
        u(r.x0, r.z1), v(r.x0, r.z1),
        u(r.x1, r.z1), v(r.x1, r.z1),
        u(r.x1, r.z0), v(r.x1, r.z0),
        u(r.x0, r.z0), v(r.x0, r.z0),
      ]);
    }

// is this perimeter cell part of the lift car's ring? The car hangs off the tower's face (gen.blocks
// .ElevatorBlock), and its floor is the only Surf.LIFT on the plate bar the door, so a post or a
// pane touching it, diagonals included for the corner posts, is the car's and its drop is the SHAFT.
// The tower's own wall either side of the car is two cells from the floor and stays glazing
  static function liftAt(m:Facility, col:Int, row:Int):Bool
    {
      for (dr in -1...2)
        for (dc in -1...2)
          if (FacilityModel.inside(m, col + dc, row + dr) &&
              m.surf[row + dr][col + dc] == Surf.LIFT)
            return true;
      return false;
    }

// the parapet's plane on this cell: the cell rect pulled in by PARAPET_INSET on every hand where
// the wall line stops. FacilityGeom.ringRect, which is private there for the same reason
  static function ring(m:Facility, col:Int, row:Int, half:Float):Rect
    {
      var e = FacilityStyle.PARAPET_INSET;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      return {
        x0: x0 + (FacilityGeom.carries(m, col - 1, row) ? 0.0 : e),
        x1: x0 + CELL - (FacilityGeom.carries(m, col + 1, row) ? 0.0 : e),
        z0: z0 + (FacilityGeom.carries(m, col, row - 1) ? 0.0 : e),
        z1: z0 + CELL - (FacilityGeom.carries(m, col, row + 1) ? 0.0 : e),
      };
    }

// the reentrant-corner squares this cell leaves open, on the RING plane.
//
// FacilityGeom.notches is the same shape and cannot be called: it measures the square off the
// cell's OWN thickness, where `ring` above forces PARAPET_INSET whatever that thickness is, and a
// glazed corner would leave the two halves of the repair half a unit apart
  static function notches(m:Facility, col:Int, row:Int, half:Float):Array<Notch>
    {
      var e = FacilityStyle.PARAPET_INSET;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      var out = [];
      for (dz in 0...2)
        for (k in 0...2)
          {
            var dx = 2 + k;
            if (!FacilityGeom.carries(m, col + DC[dz], row + DR[dz]) ||
                !FacilityGeom.carries(m, col + DC[dx], row + DR[dx]))
              continue;
            var nx = (dx == 2 ? x0 : x0 + CELL - e);
            var nz = (dz == 0 ? z0 : z0 + CELL - e);
            out.push({
              x0: nx,
              x1: nx + e,
              z0: nz,
              z1: nz + e,
              dx: dx,
              dz: dz,
              col: col + DC[dx],
              row: row + DR[dz],
            });
          }
      return out;
    }

// one merged LIT mesh, on render.corp.CorpStreet's own street moon rather than on the office's:
// the flank runs 114 units DOWN, so it is the street's surface as much as the tower's, and it both
// casts onto the road at its foot and catches the shadow of anything standing beside it.
//
// IT SHIPPED WITH NO `color:` FIELD AT ALL, i.e. at 1.0, while the street beside it wears
// STREET_DIM and the cars CAR_DIM. The facade is the largest exterior surface in the frame and the
// nearest — nineteen storeys straight down outside the window — so it was rendering at full
// authored albedo and coming out BRIGHTER than the office the player is standing in
  static function add(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        color: new Color(0xffffff).multiplyScalar(CorpStyle.FACADE_DIM),
        side: THREE.FrontSide,
      });
      // the tower's own flank runs 114 units DOWN, so its far end is exactly as distant as the
      // street is and takes the same distance blur — CorpStyle.BLUR.near is set past its top
      CorpStreet.blur(mat);
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.name = 'corp facade ' + tex;
      mesh.receiveShadow = true;
      mesh.renderOrder = CorpStyle.OUTSIDE_ORDER;
      CorpStreet.casts(mesh);
      scene.add(mesh);
    }
}
