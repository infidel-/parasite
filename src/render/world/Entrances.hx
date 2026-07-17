package render.world;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import citygen.CityModel.Building;
import render.RenderConfig;
import render.RenderConfig.TEXTURES;
import render.Textures;
import render.Poly.tag;

// pedestrian entrance / maintenance doors on simple + composite buildings, each with
// its tinted lintel/canopy cover. Front doors are guaranteed on the widest street face;
// side doors are deterministic per non-street wall. Face/run classification via Geom;
// the stone door's gable cover via Roofs.coverGableGeo. Writes doorSeen / noBackDoor.
class Entrances {
  static inline var CELL = CityConfig.CELL;

  // front: one centred door on the widest STREET face, GUARANTEED for every building (stores are
  //   covered by their storefront band instead, except when landlocked). no building is doorless.
  // side: one per NON-street wall, independent coin-flip — worn walls at BACK_ENTRANCE_WORN_PCT
  //   (a drab steel maintenance door), clean back walls rarely (BACK_ENTRANCE_CLEAN_PCT); side
  //   doors sit OFF-CENTRE along the face. the door texture matches the wall it's on (clean door
  //   on a clean face, worn door on a worn face). all deterministic — no rng, no citygen desync.
  public static function add(scene:Scene):Void {
    var buildings = WorldCtx.buildings;
    var doorTex = [for (p in TEXTURES.doors) Textures.loadTexture(p, 'wall')];
    var doorWornTex = [for (p in TEXTURES.doorsWorn) Textures.loadTexture(p, 'wall')];
    for (t in doorTex) { t.wrapS = t.wrapT = THREE.ClampToEdgeWrapping; t.needsUpdate = true; }
    for (t in doorWornTex) { t.wrapS = t.wrapT = THREE.ClampToEdgeWrapping; t.needsUpdate = true; }

    // per-facade entrance-cover lintel texture [concrete, brick, stone], world-tiled per cover.
    // NEVER a flat colour. cropped to the centre band (like coping) then cloned + repeat-set per slab.
    var coverTex = [for (p in TEXTURES.doorCovers) Textures.loadTexture(p, 'wall')]; // full material swatch (not a band)

    inline function doorSide(b:Building, faceW:Float):Float
      return Math.min(RenderConfig.DOOR_SIZE, Math.min(b.h * 0.9, faceW * 0.9));

    inline function place(b:Building, f:{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float}, off:Float, s:Float):Void {
      var worn = Geom.isWornFace(b, f.dir);
      var tx = worn ? doorWornTex[b.facade] : doorTex[b.facade];
      var k = RenderConfig.FACADE_NAMES[b.facade];
      // s = SQUARE quad side (square texture → no stretch); passed in (full face for front/composite, open-run-capped for side)
      var mat = tag(new MeshStandardMaterial({ map: tx, roughness: 1, metalness: 0,
        transparent: false, alphaTest: 0.5, // hand-painted alpha = cutout: discard the transparent wall surround (wall behind shows). matches windows
        // depth-bias BELOW the grime (-1) so the door wins the depth test flush against the wall — no
        // physical gap needed. grime is transparent+depthWrite:false, so a nearer door bias keeps grime off it.
        polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 }),
        'door-$k' + (worn ? '-worn' : ''), '$k door' + (worn ? ' (service)' : ''),
        worn ? TEXTURES.doorsWorn[b.facade] : TEXTURES.doors[b.facade]);
      WorldCtx.doorSeen.set(b, true); // checklist: this building rendered at least one door
      // publish the along-face span so WallDecals keeps graffiti off it (off = center offset, s = door side)
      WorldCtx.doorSpans.push({ b: b, dir: f.dir, lo: off - s / 2, hi: off + s / 2 });
      var mesh = new Mesh(new PlaneGeometry(s, s), mat);
      mesh.rotation.y = f.rotY;
      var eps = 0.01; // effectively flush (was 0.06 → visible gap); polygonOffset -2 does the z-fight work, this hair just guards grazing angles
      if (f.dir < 2) mesh.position.set(f.fx + off, s / 2, f.fz + (f.dir == 0 ? eps : -eps));
      else mesh.position.set(f.fx + (f.dir == 2 ? eps : -eps), s / 2, f.fz + off);
      scene.add(mesh);
    }

    // thin tinted slab (lintel/canopy) just above a FRONT door, slightly wider, jutting out.
    // mirrors place()'s lateral (off) + normal (dir) math so it lines up with the door at (off,s).
    inline function placeCover(b:Building, f:{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float}, off:Float, s:Float):Void {
      var cw = s * RenderConfig.COVER_WIDTH_FRAC;                            // ~ door-panel width (not wall-wide)
      var cd = RenderConfig.COVER_DEPTH;
      var mt = RenderConfig.COVER_MAT_TILE;
      var k = RenderConfig.FACADE_NAMES[b.facade];
      var ct = coverTex[b.facade].clone();
      ct.wrapS = ct.wrapT = THREE.RepeatWrapping;
      ct.needsUpdate = true;
      var cmat = tag(new MeshStandardMaterial({ map: ct, roughness: 1, metalness: 0, side: THREE.DoubleSide }), 'door-cover-$k', '$k door cover', TEXTURES.doorCovers[b.facade]);
      // world pos of the local origin (door-top-center on the wall), shifted `off` along the face,
      // `outN` along the outward normal. rotation.y = f.rotY makes local +z = outward for every dir.
      inline function setPos(cover:Mesh, y:Float, outN:Float):Void {
        cover.rotation.y = f.rotY;
        if (f.dir < 2) cover.position.set(f.fx + off, y, f.fz + (f.dir == 0 ? outN : -outN));
        else cover.position.set(f.fx + (f.dir == 2 ? outN : -outN), y, f.fz + off);
      }
      var anchor = s * RenderConfig.COVER_Y_FRAC; // cover BOTTOM sits here — just above the visible door, small gap
      var cover:Mesh;
      switch (b.facade) {
        case 0: // concrete: HALF-BARREL — half-cylinder, axis along door width, flat back on wall, curve bulges out
          ct.repeat.set(cw / mt, 1);
          var R = RenderConfig.COVER_BARREL_R;
          var geo = new CylinderGeometry(R, R, cw, RenderConfig.COVER_ARC_SEG, 1, false, -Math.PI / 2, Math.PI);
          geo.rotateZ(Math.PI / 2);                                        // cylinder axis Y → X (along door width); retained half faces +z (outward)
          cover = new Mesh(geo, cmat);
          setPos(cover, Math.min(anchor + R, b.h - R), -RenderConfig.COVER_EMBED); // flat diameter vertical on wall; bottom at anchor
        case 2: // stone: sloped slate cap INSET into the wall — ridge buried, only the front slope shows (grows from the wall)
          ct.repeat.set(1, 1);                                             // UVs already world-tiled inside coverGableGeo
          var geo = Roofs.coverGableGeo(cw, cd, RenderConfig.COVER_SLOPE_RISE, mt);
          cover = new Mesh(geo, cmat);
          setPos(cover, Math.min(anchor + 0.2, b.h - RenderConfig.COVER_SLOPE_RISE), -RenderConfig.COVER_EMBED); // ridge (local z=0) ~at wall → back half embedded; lifted a touch (inset slope reads higher than flat covers)
        default: // brick: THIN flat painted-metal awning slab (metal = thin)
          var ch = RenderConfig.COVER_METAL_H;
          ct.repeat.set(cw / mt, cd / mt);
          cover = new Mesh(new BoxGeometry(cw, ch, cd), cmat);
          var by = s * 0.85; // sit at the door top: a thin sheet can't hide door poking above it, so ride higher than the thick covers' anchor
          setPos(cover, Math.min(by + ch / 2, b.h - ch / 2), cd / 2 - RenderConfig.COVER_EMBED);
      }
      scene.add(cover);
    }

    // main entrance on a frontage: a thick wall (> 5 window columns wide) gets TWO doors at the
    // quarter points instead of one centred, so a wide facade doesn't read as a single lonely door.
    // each FRONT door also gets a tinted cover (service doors via sideDoor are left coverless).
    inline function placeFront(b:Building, f:{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float}, s:Float):Void {
      if (Geom.centeredCols(-f.faceW / 2, f.faceW / 2).length > 5) {
        var o = f.faceW / 4; place(b, f, -o, s); placeCover(b, f, -o, s); place(b, f, o, s); placeCover(b, f, o, s);
      } else { place(b, f, 0, s); placeCover(b, f, 0, s); }
    }

    for (b in buildings) {
      var fi = Geom.frontInfo(b);
      var composite = b.shop < 0 && b.facade != 3 && !fi.simple; // T/L/+/courtyard pieces (winForce/winBlock set)
      if (!fi.simple && !composite) continue; // shops + metal keep their own entrances
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      var faces = Geom.buildingFaces(center, wWorld, dWorld, 0);
      var doored = new haxe.ds.IntMap<Bool>(); // dirs that already carry a door (no duplicates)

      // composite (T/L/+) piece: a CENTERED door on every wall facing a street. faceIsStreet
      // already requires the cells straight out to be road/walkway, so a wall buried behind a
      // sibling piece or another building is excluded (nothing covers the path to the street).
      if (composite) {
        for (f in faces) if (Geom.faceIsStreet(b, f.dir) && !Geom.storefrontFace(b, f.dir)) { placeFront(b, f, doorSide(b, f.faceW)); doored.set(f.dir, true); }
      } else {
        // front door — GUARANTEED: every building must have one. stores already show a storefront
        // band (its own entrance) on a street face, so they only need an explicit door if they are
        // landlocked (no street face → no band). everyone else always gets a pedestrian/glass door
        // on the widest street face, falling back to the widest face so nothing is ever doorless.
        var streetFront:{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float} = null;
        var anyFront:{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float} = null;
        for (f in faces) {
          if (anyFront == null || f.faceW > anyFront.faceW) anyFront = f;
          if (Geom.faceIsStreet(b, f.dir) && (streetFront == null || f.faceW > streetFront.faceW)) streetFront = f;
        }
        if (!fi.store || streetFront == null) { // store with a street face is covered by its band
          var front = streetFront != null ? streetFront : anyFront;
          if (front != null) { placeFront(b, front, doorSide(b, front.faceW)); doored.set(front.dir, true); }
        }

        // side / maintenance doors: each non-street wall independent, off-centre. The door must sit
        // in an OPEN run of the wall (doorRuns = the part not buried behind a neighbour) and keep
        // DOOR_EDGE_CLEAR clear of the run's ends — which are the corners, including a T/L-junction
        // where a sibling piece abuts. too narrow a run → no room → no door. Returns true if placed.
        function sideDoor(f:{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float}):Bool {
          var runs = Geom.doorRuns(b, f.dir);
          if (runs.length == 0) return false;
          var best = runs[0];
          for (rr in runs) if ((rr.hi - rr.lo) > (best.hi - best.lo)) best = rr;
          var runW = (best.hi - best.lo + 1) * CELL;
          var mid = (f.dir < 2)
            ? (cellToWorld(best.lo, b.row).x + cellToWorld(best.hi, b.row).x) / 2 - center.x
            : (cellToWorld(b.col, best.lo).z + cellToWorld(b.col, best.hi).z) / 2 - center.z;
          var s = Math.min(RenderConfig.DOOR_SIZE, Math.min(b.h * 0.9, runW - 2 * RenderConfig.DOOR_EDGE_CLEAR));
          if (s < RenderConfig.DOOR_MIN) return false; // run too narrow to fit a door clear of the corners
          var r = ((b.col * 92837111) ^ (b.row * 689287499) ^ (f.dir * 283923481)) & 0x7fffffff;
          var maxJit = Math.max(0, runW / 2 - s / 2 - RenderConfig.DOOR_EDGE_CLEAR);
          place(b, f, mid + ((r >> 8) % 1001 / 1000 * 2 - 1) * maxJit, s);
          return true;
        }
        var nonStreet = [for (f in faces) if (!Geom.faceIsStreet(b, f.dir)) f];
        var placedSide = false;
        for (f in nonStreet) {
          var r = ((b.col * 92837111) ^ (b.row * 689287499) ^ (f.dir * 283923481)) & 0x7fffffff;
          var pct = Geom.isWornFace(b, f.dir) ? RenderConfig.BACK_ENTRANCE_WORN_PCT : RenderConfig.BACK_ENTRANCE_CLEAN_PCT;
          if (r % 100 < pct && sideDoor(f)) { placedSide = true; doored.set(f.dir, true); }
        }
        if (!placedSide) for (f in nonStreet) if (sideDoor(f)) { placedSide = true; doored.set(f.dir, true); break; } // guarantee: first back wall with room
        // checklist: flag a building that has an open back wall yet got no side door (all runs
        // too narrow for corner clearance) — informational, not a hard failure
        if (!placedSide) for (f in nonStreet) if (Geom.doorRuns(b, f.dir).length > 0) { WorldCtx.noBackDoor.push(b); break; }
      }

      // extra entrance: a windowed wall with a clear straight path to a road gets its OWN door —
      // even off the street, even if the building already has a front door. a corner/island
      // building facing a road across an alley or walkway shouldn't present a doorless wall to it.
      // a store's street wall already shows a storefront (its entrance) — never door over that.
      if (Geom.expectWindows(b)) for (f in faces)
        if (!doored.exists(f.dir) && !Geom.storefrontFace(b, f.dir) && Geom.faceHasPathToRoad(b, f.dir)) { placeFront(b, f, doorSide(b, f.faceW)); doored.set(f.dir, true); }
    }
  }
}
