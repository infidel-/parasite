package render;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import citygen.CityConfig.worldToCell;
import citygen.CityModel.Building;
import citygen.CityModel.Tile;

// one fadeable building mesh + its lazily-built ghost overlay: a geometry-sharing clone whose
// materials sample no shadow maps (lit Lambert for a lit source, MeshBasic for an unlit one). as the
// building fades, the ghost dissolves IN over
// the still-solid real (cross-dissolving lit->ghost with no appearance pop); once it fully covers,
// the real is hidden and the ghost eases on down to see-through. cheap per fragment, so the
// see-through overdraw no longer pays the full shadowed PBR
typedef FadeMesh = { mesh:Dynamic, ghost:Dynamic, ghostVisible:Bool, realHidden:Bool };
// per-building fade record: its world AABB, its fadeable meshes, and the eased fade
typedef Occ = {
  b:Building,
  minX:Float, maxX:Float, minZ:Float, maxZ:Float, maxY:Float, cx:Float, cz:Float,
  meshes:Array<FadeMesh>, fade:Float, target:Float,
  plate:Mesh,   // flat ground fill marker, shown only while this building is faded
  outline:Mesh  // glowing emissive band hugging the footprint edge (visible under any lighting)
};

// fades a building to a translucent ghost while it sits between the camera and the player, so
// the player never hides behind a wall. Built once per city: derives each building's world
// AABB and buckets every scene mesh into the building it belongs to (by userData.b, else by
// position + a size guard — see pick). Each frame a segment/AABB slab test picks the occluders and
// eases a fade; a faded mesh swaps to a cheap ghost material that samples no shadow maps, so the
// see-through overdraw is affordable. StreetView owns and drives it.
class Occlusion {
  static inline var CELL = CityConfig.CELL;
  static var checked = false;

  var occ:Array<Occ> = [];
  var skipped:Array<Dynamic> = []; // meshes pick() left unbucketed (never fade) — __occ.skipped()
  var tiles:Array<Array<Tile>>;
  var tactical = false;
  var tacticalSelected:haxe.ds.ObjectMap<Building, Bool> = new haxe.ds.ObjectMap();
  var tacticalCol = -1;
  var tacticalRow = -1;
  var tacticalColDir = 0;
  var tacticalRowDir = 0;

  public function new(scene:Scene, buildings:Array<Building>, tiles:Array<Array<Tile>>)
    {
      this.tiles = tiles;
      if (!checked) { checked = true; if (!demo()) js.Browser.console.warn('[occlusion] self-check FAILED'); }
      // one fade record + world AABB per building; map Building -> index for userData bucketing
      var idxOf = new haxe.ds.ObjectMap<Building, Int>();
      for (i in 0...buildings.length)
        {
          var b = buildings[i];
          var c = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
          var hw = b.w * CELL / 2, hd = b.d * CELL / 2;
          // top the AABB at the parapet, not the roofline: the parapet rim sits above b.h and
          // can hide the player while the wall grazes clear — cover the tallest (brick) variant
          occ.push({
            b: b,
            minX: c.x - hw,
            maxX: c.x + hw,
            minZ: c.z - hd,
            maxZ: c.z + hd,
            maxY: b.h + RenderConfig.PARAPET_H_BRICK,
            cx: c.x,
            cz: c.z,
            meshes: [],
            fade: 1.0,
            target: 1.0,
            plate: makePlate(scene, c.x, c.z, b.w * CELL, b.d * CELL),
            outline: makeOutline(scene, c.x, c.z, b.w * CELL, b.d * CELL),
          });
          idxOf.set(b, i);
        }
      // bucket every mesh into its building and register each material slot for fading
      scene.traverse(function(o:Object3D) {
        if (untyped o.isMesh != true && o.isInstancedMesh != true) return;
        // skip our own footprint markers (already in the scene): bucketing them would fold their
        // material into the building's fade set and clobber the opacity we drive in apply()
        if (untyped o.userData != null && o.userData.occMarker == true) return;
        var bi = pick(o, idxOf);
        if (bi < 0)
          {
            // unbucketed = never fades. the ground/lamp/roof-shadow meshes land here by design
            // (see pick), so record them: a future world-baked mesh that silently stops fading
            // with its building shows up in this list instead of being invisible
            var s = xzSize(o);
            var mm:Dynamic = o.material;
            skipped.push({
              cls: StreetPerf.matCls(Std.isOfType(mm, Array) ? (mm : Array<Dynamic>)[0] : mm),
              size: [Math.round(s.x * 10) / 10, Math.round(s.z * 10) / 10],
            });
            return;
          }
        if (o.material == null) return;
        occ[bi].meshes.push({ mesh: o, ghost: null, ghostVisible: false, realHidden: false });
      });
      attachDbg();
    }

// console debug helpers (persistent) — what each building actually fades.
//   __occ.stats()   -> { buildings, meshes, skipped }
//   __occ.skipped() -> [{ cls, size:[x,z] }]  meshes pick() left unbucketed, so they never fade:
//                      the city-wide ground/lamp/roof-shadow meshes (by design), plus anything the
//                      size guard rejected. audits the guard's own decisions
  function attachDbg():Void
    {
      untyped js.Browser.window.__occ = {
        stats: function()
          {
            var n = 0;
            for (o in occ)
              n += o.meshes.length;
            return {
              buildings: occ.length,
              meshes: n,
              skipped: skipped.length,
            };
          },
        skipped: function() return skipped,
      };
    }

// build one building-footprint marker: a flat semi-transparent quad laid on the ground over the
// footprint, hidden until the building fades (opacity driven in apply). building cells are
// unpaved, so this is the only sign a see-through building still stands there
  function makePlate(scene:Scene, cx:Float, cz:Float, w:Float, d:Float):Mesh
    {
      var m = new Mesh(
        new PlaneGeometry(w, d),
        new MeshBasicMaterial({
          color: RenderConfig.OCCLUSION.plateColor,
          transparent: true,
          opacity: 0.0,
          depthWrite: false,
        }));
      m.rotation.x = -Math.PI / 2;
      m.position.set(cx, RenderConfig.OCCLUSION.plateY, cz);
      m.visible = false;
      untyped m.userData.occMarker = true; // exclude from the de-share bucketing traverse
      scene.add(m);
      return m;
    }

// build the glowing footprint outline: a DASHED thin ground line tracing the footprint perimeter,
// in the tactical-grid recipe (HDR MeshBasic quad strip, toneMapped off) so it blooms and reads
// under any lighting. hidden until the building fades (opacity driven in apply)
  function makeOutline(scene:Scene, cx:Float, cz:Float, w:Float, d:Float):Mesh
    {
      var ox = w / 2, oz = d / 2;                            // footprint half-extents (edge)
      var hw = CELL * RenderConfig.OCCLUSION.outlineWidth;   // dash half-width (world)
      var dash = RenderConfig.OCCLUSION.outlineDash, gap = RenderConfig.OCCLUSION.outlineGap;
      var lift = RenderConfig.OCCLUSION.plateY + 0.02;       // rest this far above the ground surface
      var pos:Array<Float> = [];
      var idx:Array<Int> = [];
      // one dash quad from (ax,az) to (bx,bz) at local height qy, widened by hw across its normal
      inline function quad(ax:Float, az:Float, bx:Float, bz:Float, qy:Float):Void
        {
          var base = Std.int(pos.length / 3);
          if (az == bz)
            {
              // x-run: widen across z
              pos.push(ax); pos.push(qy); pos.push(az - hw);
              pos.push(bx); pos.push(qy); pos.push(az - hw);
              pos.push(bx); pos.push(qy); pos.push(az + hw);
              pos.push(ax); pos.push(qy); pos.push(az + hw);
            }
          else
            {
              // z-run: widen across x
              pos.push(ax - hw); pos.push(qy); pos.push(az);
              pos.push(ax + hw); pos.push(qy); pos.push(az);
              pos.push(ax + hw); pos.push(qy); pos.push(bz);
              pos.push(ax - hw); pos.push(qy); pos.push(bz);
            }
          idx.push(base); idx.push(base + 2); idx.push(base + 1);
          idx.push(base); idx.push(base + 3); idx.push(base + 2);
        }
      // walk one axis-aligned edge, emitting a dash every dash+gap over its full length. each dash
      // rests on the surface OUTSIDE the footprint edge (odx,odz = outward normal): a walkway there
      // sits a curb above the road, so a flat line would tunnel under it — sample the floor per dash
      function edge(x0:Float, z0:Float, x1:Float, z1:Float, odx:Float, odz:Float):Void
        {
          var dx = x1 - x0, dz = z1 - z0;
          var L = Math.sqrt(dx * dx + dz * dz);
          if (L < 1e-4)
            return;
          var ux = dx / L, uz = dz / L;
          var t = 0.0;
          while (t < L)
            {
              var e = Math.min(t + dash, L);
              // sample the cell just outside the edge at the dash midpoint (world coords = local + center)
              var mid = (t + e) / 2;
              var sc = worldToCell(cx + x0 + ux * mid + odx * CELL * 0.5,
                                   cz + z0 + uz * mid + odz * CELL * 0.5);
              var qy = render.world.WorldCtx.floorY(sc.col, sc.row) + lift;
              quad(x0 + ux * t, z0 + uz * t, x0 + ux * e, z0 + uz * e, qy);
              t += dash + gap;
            }
        }
      edge(-ox, -oz, ox, -oz, 0, -1); // top (-z)
      edge(-ox, oz, ox, oz, 0, 1);    // bottom (+z)
      edge(-ox, -oz, -ox, oz, -1, 0); // left (-x)
      edge(ox, -oz, ox, oz, 1, 0);    // right (+x)
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geo.setIndex(idx);
      // HDR color (past 1) + toneMapped off = crosses the bloom threshold for a soft glow, like
      // the tactical grid; unlit MeshBasic so it reads under any scene lighting
      var m = new Mesh(geo,
        new MeshBasicMaterial({
          color: new Color(RenderConfig.OCCLUSION.outlineColor).multiplyScalar(RenderConfig.OCCLUSION.outlineGlow),
          transparent: true,
          opacity: 0.0,
          depthWrite: false,
          toneMapped: false,
          side: THREE.DoubleSide,
        }));
      m.position.set(cx, 0, cz); // dash verts already carry their per-dash world height
      m.visible = false;
      m.renderOrder = 1;
      untyped m.userData.occMarker = true; // exclude from the de-share bucketing traverse
      scene.add(m);
      return m;
    }

// enable or clear the road-bounded tactical building selection
  public function setTactical(v:Bool):Void
    {
      if (tactical == v)
        return;
      tactical = v;
      tacticalCol = -1;
      tacticalRow = -1;
      if (!tactical)
        tacticalSelected = new haxe.ds.ObjectMap();
    }

// world XZ size of a mesh, instances included: Box3.setFromObject unions over an InstancedMesh's
// per-instance matrices, which is where the city-wide spread of the lamps/roof-shadows lives —
// their geometry is one small quad at the origin. SIZE, not position: the static-city chunk groups
// have matrixWorldAutoUpdate off (see makeGhostMesh), so a matrixWorld here may be stale, and size
// is translation-invariant. XZ only: a 3D radius is dominated by a building's HEIGHT
  static function xzSize(o:Object3D):Vector3
    {
      return new Box3().setFromObject(o).getSize(new Vector3());
    }

// which building a mesh belongs to: its userData.b tag if present (box + window meshes),
// else the nearest-centre building whose AABB (margin-expanded for face-proud decals) holds it
// AND whose footprint is big enough to contain it. -1 = belongs to no building, never fades
  function pick(o:Object3D, idxOf:haxe.ds.ObjectMap<Building, Int>):Int
    {
      var b:Building = (o.userData != null) ? o.userData.b : null;
      if (b != null && idxOf.exists(b)) return idxOf.get(b); // tag wins: mergeBand/gable roofs are
                                                             // world-baked at (0,0,0) too, and only
                                                             // the tag saves them from the size guard
      var px = o.position.x, pz = o.position.z, m = RenderConfig.OCCLUSION.margin;
      var size = xzSize(o);
      var best = -1;
      var bestD = 1e18;
      for (i in 0...occ.length)
        {
          var e = occ[i];
          if (px < e.minX - m || px > e.maxX + m || pz < e.minZ - m || pz > e.maxZ + m) continue;
          // a mesh wider than the building itself cannot be part of it. world-baked geometry and
          // instanced city-wide meshes never set position, so they sit at (0,0,0) — the exact grid
          // centre — and would otherwise bucket into whatever building covers it and go see-through
          // with it. CELL of slack: a parapet coping rim overhangs its own footprint by ~0.74
          if (size.x > (e.maxX - e.minX) + CELL || size.z > (e.maxZ - e.minZ) + CELL) continue;
          var dx = px - e.cx, dz = pz - e.cz, d = dx * dx + dz * dz;
          if (d < bestD) { bestD = d; best = i; }
        }
      return best;
    }

// does this source material sample lights? unlit MeshBasic facades must stay unlit as ghosts
  static inline function isLit(m:Dynamic):Bool
    return untyped m.isMeshBasicMaterial != true;

// build one stand-in material for a faded facade slot: for a LIT source, a LIT-but-shadowless Lambert
// (the ghost mesh keeps receiveShadow off, so it samples the moon/lamps but not the shadow maps — the
// expensive part). the building mats are pure diffuse (roughness 1, metalness 0), so this matches the
// real's shading closely and the cross-dissolve barely shifts brightness. blended + depth-open so it
// reads see-through; emissive carried over so lit windows still glow while faded.
// `lit` false -> unlit MeshBasic, matching an unlit source (see makeGhostMesh: a lit ghost over
// normal-less geometry renders NaN, and bloom smears that NaN over the whole frame)
  static function makeGhost(real:Dynamic, lit:Bool):Dynamic
    {
      var opts = {
        map: real.map,
        transparent: true,
        opacity: 1.0,
        depthWrite: false,
        fog: true,
        side: real.side,
      };
      var g:Dynamic = lit ? new MeshLambertMaterial(opts) : new MeshBasicMaterial(opts);
      // ghostDim is a small tint/dim knob (1.0 = match the lit real); the lighting supplies brightness
      var col:Dynamic = (real.color != null ? real.color.clone() : new Color(0xffffff));
      col.multiplyScalar(RenderConfig.OCCLUSION.ghostDim);
      g.color = col;
      if (real.emissive != null)
        g.emissive = real.emissive.clone();
      if (real.emissiveMap != null)
        g.emissiveMap = real.emissiveMap;
      if (real.emissiveIntensity != null)
        g.emissiveIntensity = real.emissiveIntensity;
      // keep the source alpha cutout (window frames, cut-out details) so the ghost holds its silhouette
      if (real.alphaMap != null)
        g.alphaMap = real.alphaMap;
      if (real.alphaTest != null && real.alphaTest > 0)
        g.alphaTest = real.alphaTest;
      return g;
    }

// build the ghost OVERLAY mesh for a real building mesh: a geometry-sharing clone (Mesh or
// InstancedMesh) carrying ghost materials, parked in the scene next to the real at the same
// transform, hidden until the fade needs it. drawn ON TOP of the still-solid real during the
// cross-dissolve, then alone once the real hides
  static function makeGhostMesh(real:Dynamic):Dynamic
    {
      var m:Dynamic = real.material;
      // a ghost may only go LIT when the geometry actually carries normals: the single-story shopfronts
      // ship an unlit MeshBasic over position+uv geometry, and a lit material reading the absent normal
      // renders NaN fragments — which bloom then blurs across the entire frame (whole screen goes black)
      var hasNormals = untyped real.geometry.attributes.normal != null;
      var gmat:Dynamic = Std.isOfType(m, Array)
        ? [for (mm in (m : Array<Dynamic>)) makeGhost(mm, hasNormals && isLit(mm))]
        : makeGhost(m, hasNormals && isLit(m));
      var gm:Dynamic;
      if (untyped real.isInstancedMesh == true)
        {
          // size the ghost by the source's CAPACITY, not its live count: pooled/culled instanced meshes
          // (Models.cull packs visible instances per frame, DecalBatch allocates at CAP) keep a full-size
          // instanceMatrix and drive count down under it, so allocating by count overflows the copy below
          var cap = Std.int((untyped real.instanceMatrix.array.length) / 16);
          gm = new InstancedMesh(real.geometry, gmat, cap);
          untyped gm.instanceMatrix.array.set(real.instanceMatrix.array);
          untyped gm.instanceMatrix.needsUpdate = true;
          gm.count = real.count;
        }
      else
        gm = new Mesh(real.geometry, gmat);
      gm.position.copy(real.position);
      gm.quaternion.copy(real.quaternion);
      gm.scale.copy(real.scale);
      // the ghost carries the real's shadow casting: the shadow pass renders its own depth material
      // (ignores the ghost's blend/depthWrite=false), so while the real is hidden the ghost still
      // casts the building's moon/lamp shadow — no shadow drop-out on fade
      gm.castShadow = (real.castShadow == true);
      untyped gm.userData.occMarker = true; // exclude from any re-bucketing traverse
      gm.visible = false;
      real.parent.add(gm);
      // the static-city chunk groups have matrixWorldAutoUpdate off, so this subtree is skipped by the
      // per-frame matrix walk — bake the ghost's world matrix here or it would render at the origin
      gm.updateMatrixWorld(true);
      return gm;
    }

// drive the overlay's blend (all its ghost slots share one eased opacity)
  static function setGhostOpacity(ghost:Dynamic, op:Float):Void
    {
      var m:Dynamic = ghost.material;
      if (Std.isOfType(m, Array))
        {
          var arr:Array<Dynamic> = m;
          for (mm in arr) mm.opacity = op;
        }
      else m.opacity = op;
    }

// per frame: fade buildings blocking the camera->player sightline; while aiming (wide) widen
// the corridor so flanking buildings fade too, and always clear the camera->target line (nullable
// target). only foreground buildings (nearer the camera than the endpoint) fade — never the
// background. ease every non-resting building toward its target
  public function update(camPos:Vector3, player:Vector3, target:Vector3, wide:Bool, dtMs:Float):Void
    {
      // frame-rate-independent smoothing (same exponential decay as CameraRig zoom)
      var k = 1 - Math.pow(1 - RenderConfig.OCCLUSION.lerp, dtMs / (1000 / 30));
      var grow = wide ? RenderConfig.OCCLUSION.aimGrow * CELL : 0.0;
      if (tactical)
        updateTacticalSelection(camPos, player);
      for (o in occ)
        {
          // tactical fades the whole selected block, but the camera is not truly top-down —
          // keep the sightline fade on top so an adjacent tall building never hides the player
          var blocked = (tactical && tacticalSelected.exists(o.b)) ||
            occludes(o, camPos, player, grow) ||
            (target != null && occludes(o, camPos, target, grow));
          o.target = blocked ? RenderConfig.OCCLUSION.fade : 1.0;
          if (o.fade == o.target && o.target == 1.0) continue; // solid and staying solid
          o.fade += (o.target - o.fade) * k;
          if (Math.abs(o.fade - o.target) < RenderConfig.OCCLUSION.snap) o.fade = o.target;
          apply(o);
        }
    }

// select every building in the nearest camera-side block bounded by roads
  function updateTacticalSelection(cam:Vector3, player:Vector3):Void
    {
      var cell = worldToCell(player.x, player.z);
      var dx = cam.x - player.x;
      var dz = cam.z - player.z;
      var dc = 0;
      var dr = 0;
      if (Math.abs(dx) > Math.abs(dz))
        dc = dx > 0 ? 1 : -1;
      else
        dr = dz > 0 ? 1 : -1;
      if (cell.col == tacticalCol &&
          cell.row == tacticalRow &&
          dc == tacticalColDir &&
          dr == tacticalRowDir)
        return;
      tacticalCol = cell.col;
      tacticalRow = cell.row;
      tacticalColDir = dc;
      tacticalRowDir = dr;
      tacticalSelected = new haxe.ds.ObjectMap();

      var onRoad = nearRoad(cell.col, cell.row);
      // inside a block the scans stay road-bounded: an alley must select the SURROUNDING
      // block, not wander down its length across roads to some block across town
      selectBlock(cell.col, cell.row, dc, dr, !onRoad);
      // fade the flanking blocks too: on/beside a road the view corridor runs along it and
      // the camera-side scan misses them; inside a block the side scans find the alley's own
      // walls. road-bounded so a scan along the road degrades to a no-op
      selectBlock(cell.col, cell.row, dr, dc, true);
      selectBlock(cell.col, cell.row, -dr, -dc, true);
    }

// player cell is a road, or a walkway bordering one (a sidewalk); deep-in-block walkways and
// alleys don't count — flanking fades there would strip cover the player is actually behind
  function nearRoad(col:Int, row:Int):Bool
    {
      if (tiles[row][col] == Tile.Road)
        return true;
      if (tiles[row][col] != Tile.Walkway)
        return false;
      var rows = tiles.length;
      var cols = tiles[0].length;
      for (dir in 0...4)
        {
          var c = col + (dir == 0 ? 1 : dir == 1 ? -1 : 0);
          var r = row + (dir == 2 ? 1 : dir == 3 ? -1 : 0);
          if (c >= 0 &&
              r >= 0 &&
              c < cols &&
              r < rows &&
              tiles[r][c] == Tile.Road)
            return true;
        }
      return false;
    }

// add every building of the first road-bounded block hit scanning from a cell in a direction
  function selectBlock(col:Int, row:Int, dc:Int, dr:Int, stopAtRoad:Bool):Void
    {
      var seen = tacticalBlock(tiles, col, row, dc, dr, stopAtRoad);
      if (seen == null)
        return;
      for (o in occ)
        if (isSelected(o.b, seen))
          tacticalSelected.set(o.b, true);
    }

// find the road-bounded city block first reached from a player cell in one direction;
// stopAtRoad keeps the scan inside the starting block (null once it would cross a road)
  static function tacticalBlock(tiles:Array<Array<Tile>>, playerCol:Int, playerRow:Int,
      dc:Int, dr:Int, stopAtRoad:Bool = false):Array<Array<Bool>>
    {
      var rows = tiles.length;
      var cols = tiles[0].length;
      var col = playerCol + dc;
      var row = playerRow + dr;
      var scan = rows + cols;
      for (_ in 0...scan)
        {
          if (col < 0 ||
              row < 0 ||
              col >= cols ||
              row >= rows)
            return null;
          if (tiles[row][col] == Tile.Building)
            break;
          if (stopAtRoad &&
              tiles[row][col] == Tile.Road)
            return null;
          col += dc;
          row += dr;
        }
      if (col < 0 ||
          row < 0 ||
          col >= cols ||
          row >= rows ||
          tiles[row][col] != Tile.Building)
        return null;

      var seen = [for (_ in 0...rows) [for (_ in 0...cols) false]];
      var queue:Array<{ col:Int, row:Int }> = [
        {
          col: col,
          row: row,
        },
      ];
      seen[row][col] = true;
      var next = 0;
      while (next < queue.length)
        {
          var here = queue[next++];
          for (dir in 0...4)
            {
              var nextCol = here.col + (dir == 0 ? 1 : dir == 1 ? -1 : 0);
              var nextRow = here.row + (dir == 2 ? 1 : dir == 3 ? -1 : 0);
              if (nextCol < 0 ||
                  nextRow < 0 ||
                  nextCol >= cols ||
                  nextRow >= rows ||
                  seen[nextRow][nextCol] ||
                  tiles[nextRow][nextCol] == Tile.Road)
                continue;
              seen[nextRow][nextCol] = true;
              queue.push({
                col: nextCol,
                row: nextRow,
              });
            }
        }
      return seen;
    }

// return whether any cell in a building belongs to the selected road-bounded block
  function isSelected(b:Building, seen:Array<Array<Bool>>):Bool
    {
      for (row in b.row...b.row + b.d)
        for (col in b.col...b.col + b.w)
          if (seen[row][col])
            return true;
      return false;
    }

// building o blocks camera->endpoint? only counts if o is in FRONT of the endpoint (its centre
// projects nearer the camera than the endpoint) so a grown corridor never fades the background
  inline function occludes(o:Occ, cam:Vector3, e:Vector3, grow:Float):Bool
    {
      var dx = e.x - cam.x, dz = e.z - cam.z, d2 = dx * dx + dz * dz;
      if (d2 < 1e-6) return false;
      var proj = ((o.cx - cam.x) * dx + (o.cz - cam.z) * dz) / d2; // 0=camera, 1=endpoint
      if (proj >= 1.0) return false;                               // at/behind endpoint = background
      return segHitsBox(cam.x, cam.y, cam.z, e.x, e.y, e.z,
        o.minX, o.maxX, o.minZ, o.maxZ, o.maxY, grow);
    }

// push the current fade onto a building: cross-dissolve the ghost overlay IN over the still-solid
// real while f eases from 1 down to ghostCross, then hide the real and ease the ghost on down to the
// see-through target. reverse on un-fade. no appearance pop — the lit->unlit change is a dissolve
  function apply(o:Occ):Void
    {
      var f = o.fade;
      var C = RenderConfig.OCCLUSION;
      // footprint marker: fade-in the ground plate + glowing edge outline as the building goes
      // see-through (both hidden while solid). the outline self-emits so it reads under any lighting
      var faded = f < 0.999;
      o.plate.visible = faded;
      untyped o.plate.material.opacity = (1 - f) * C.plateAlpha;
      o.outline.visible = faded;
      untyped o.outline.material.opacity = (1 - f) * C.outlineAlpha;
      // the fade SNAPS to its target within `snap` (crisp window bloom on solidify), so the ghost
      // must be fully OUT (solid) above `hi` and flat at the see-through `rest` below `lo` — else the
      // snap jump removes/adds a mid-opacity ghost in one frame = a pop. cross-dissolve only in
      // between: ghost eases IN over the still-solid real from hi down to mid, then the real hides and
      // the ghost eases on to rest from mid down to lo
      var mid = C.ghostCross;   // ghost fully covers here (real hidden below)
      var rest = C.fade;        // see-through opacity at rest
      var hi = 1 - C.snap;      // at/above: solid (snap parks the fade at 1.0 up here)
      var lo = rest + C.snap;   // at/below: parked see-through (snap parks the fade at rest down here)
      var solid = f >= hi;
      for (fm in o.meshes)
        {
          if (solid)
            {
              if (fm.ghostVisible) { fm.ghost.visible = false; fm.ghostVisible = false; }
              if (fm.realHidden) { fm.mesh.visible = true; fm.realHidden = false; }
              continue;
            }
          if (fm.ghost == null)
            fm.ghost = makeGhostMesh(fm.mesh);
          if (!fm.ghostVisible) { fm.ghost.visible = true; fm.ghostVisible = true; }
          var op:Float;
          if (f >= mid)
            {
              // cross-dissolve: ghost fades IN (0 at hi -> 1 at mid) over the still-visible real
              if (fm.realHidden) { fm.mesh.visible = true; fm.realHidden = false; }
              op = (hi - f) / (hi - mid);
            }
          else
            {
              // ghost fully covers: hide the real, ease the ghost from 1 (at mid) down to rest (at lo)
              if (!fm.realHidden) { fm.mesh.visible = false; fm.realHidden = true; }
              op = f <= lo ? rest : rest + (f - lo) / (mid - lo) * (1 - rest);
            }
          setGhostOpacity(fm.ghost, op);
        }
    }

// does segment a->b pass through the box (strictly between the endpoints)? slab clip. grow
// inflates the XZ slabs, widening the corridor (used to fade near-line, not just strict, hits)
  static function segHitsBox(ax:Float, ay:Float, az:Float, bx:Float, by:Float, bz:Float,
    x0:Float, x1:Float, z0:Float, z1:Float, y1:Float, grow:Float = 0.0):Bool
    {
      var t = [0.0, 1.0];
      if (!clip(ax, bx, x0 - grow, x1 + grow, t)) return false;
      if (!clip(ay, by, 0, y1, t)) return false;
      if (!clip(az, bz, z0 - grow, z1 + grow, t)) return false;
      return t[1] > 0.001 && t[0] < 0.999 && t[0] <= t[1];
    }

// clip param range t=[enter,exit] against one axis slab [lo,hi]; false if it empties the range
  static function clip(p0:Float, p1:Float, lo:Float, hi:Float, t:Array<Float>):Bool
    {
      var d = p1 - p0;
      if (d > -1e-9 && d < 1e-9) return p0 >= lo && p0 <= hi; // parallel: inside slab or miss
      var ta = (lo - p0) / d, tb = (hi - p0) / d;
      if (ta > tb) { var tmp = ta; ta = tb; tb = tmp; }
      if (ta > t[0]) t[0] = ta;
      if (tb < t[1]) t[1] = tb;
      return t[0] <= t[1];
    }

// self-check for the slab test: a box on the line hits, boxes beside/behind it miss
  static function demo():Bool
    {
      // box [-1..1]^3-ish straddling the segment from (0,0,-10) to (0,0,10)
      var hit = segHitsBox(0, 0, -10, 0, 0, 10, -1, 1, -1, 1, 2);
      // box off to the side of the same line
      var side = segHitsBox(0, 0, -10, 0, 0, 10, 5, 7, -1, 1, 2);
      // box beyond the far endpoint (player at z=10, box at z=20..22)
      var beyond = segHitsBox(0, 0, -10, 0, 0, 10, -1, 1, 20, 22, 2);
      var tiles:Array<Array<Tile>> = [
        [Tile.Road, Tile.Road, Tile.Road, Tile.Road, Tile.Road, Tile.Road],
        [Tile.Road, Tile.Walkway, Tile.Building, Tile.Alley, Tile.Building, Tile.Road],
        [Tile.Road, Tile.Road, Tile.Road, Tile.Road, Tile.Road, Tile.Road],
      ];
      var block = tacticalBlock(tiles, 1, 1, 1, 0);
      var tactical = block != null &&
        block[1][2] &&
        block[1][4] &&
        !block[1][0] &&
        !block[1][5];
      // road-bounded scan: walking toward the road must yield nothing, not cross it
      var stopped = tacticalBlock(tiles, 1, 1, -1, 0, true);
      return hit && !side && !beyond && tactical && stopped == null;
    }
}
