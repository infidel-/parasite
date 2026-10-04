package render.sewer;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.sewer.SewerModel.Sewer;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// one shallow pool on the walkway: a cell of the water-pools atlas, centred at (x,z), w x d world
// units, turned `ang` about the vertical
typedef SewerPool = {
  // centre, world x
  x:Float,
  // centre, world z
  z:Float,
  // footprint width in world units (the atlas cell's own aspect, never stretched)
  w:Float,
  // footprint depth in world units
  d:Float,
  // yaw about the vertical, radians
  ang:Float,
  // which atlas cell (an index into SewerStyle.POOL_RECTS)
  cell:Int,
};

// everything the water pass places, split from the build so a layout can be read without a scene —
// parasiteHx['render.sewer.SewerWater'].layout(SewerModel.demo())
typedef SewerWaterLayout = {
  // standing pools
  pools:Array<SewerPool>,
};

// standing water on the walkway. the third attempt at water down here, and the first that is not
// darker albedo: the sludge gutter read as a dark stripe and the Lambert puddles as faint smears,
// because a Lambert surface under this much ambient can only say "water" by being darker, and darker
// reads as a pit. this is a MeshStandardMaterial at low roughness, so the overhead shafts and the
// wall brackets put a real glint on it — the one thing that reads as liquid at this pitch — while
// its albedo sits at 0.8x the walkway's. a node lamp's glint lands toward the camera by
// bulbY / tan(pitch), ~4.2 units at the near pose and ~2.0 at the far one, so the lamp pools are
// pushed south off their lamp by LAMP_POOL_SOUTH to sit under it at both.
// derived from the cell grid like every other sewer pass: deterministic, persisted nowhere
class SewerWater
{
  static inline var CELL = CityConfig.CELL;

// the water meshes into the scene
  public static function build(scene:Scene, m:Sewer):Void
    {
      var lay = layout(m);
      var pools = MeshBufTools.make();
      var R = SewerStyle.POOL_RECTS;
      for (p in lay.pools)
        {
          var r = R[p.cell];
          quad(pools, p, [r[0], r[3], r[2], r[3], r[2], r[1], r[0], r[1]]);
        }
      // built even when the level rolled no pool: the warm demo tunnel may well roll none, and a
      // mesh that is never added is a program that compiles on the first real entry instead. an
      // empty index range submits no draw call
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pools.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(pools.uv, 2));
      geo.setIndex(pools.idx);
      geo.computeVertexNormals();
      // nearly opaque on purpose: three multiplies the specular by the fragment alpha too, so the
      // 0.3 the old puddles ran at would have kept a third of the glint. the albedo is what keeps
      // it from reading as a hole, not the blend
      var mesh = new Mesh(geo, VisionMask.patch(new MeshStandardMaterial({
        map: Textures.loadTexture(SewerStyle.WATER_POOLS, 'roof'),
        roughness: SewerStyle.POOL_ROUGH,
        metalness: 0.0,
        transparent: true,
        opacity: SewerStyle.POOL_ALPHA,
        alphaTest: 0.3,
        depthWrite: false,
        side: THREE.FrontSide,
        polygonOffset: true,
        polygonOffsetFactor: -2,
        polygonOffsetUnits: -2,
      })));
      mesh.receiveShadow = true;
      scene.add(mesh);
    }

// where every pool goes. two sources: one under most corridor-node lamps (where the glint is), and a
// sparse per-2x2-block scatter for the rest of the walkway
  public static function layout(m:Sewer):SewerWaterLayout
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var pools:Array<SewerPool> = [];
      // the lamp pools first, so the scatter can keep clear of them
      for (l in m.lamps)
        {
          if (l.exit)
            continue;
          var hh = SewerModel.mix((l.col * 73856093) ^ (l.row * 19349663));
          if (hh % 100 >= SewerStyle.LAMP_POOL_PCT)
            continue;
          var w = CityConfig.cellToWorld(l.col, l.row);
          place(m, pools, w.x, w.z + SewerStyle.LAMP_POOL_SOUTH, SewerStyle.POOL_MAX, hh);
        }
      var lampPools = pools.length;
      for (brow in 0...Std.int((m.h + 1) / 2))
        for (bcol in 0...Std.int((m.w + 1) / 2))
          {
            var bc = bcol * 2;
            var br = brow * 2;
            var hh = SewerModel.mix((bc * 83492791) ^ (br * 29765723));
            var cells = [];
            for (dr in 0...2)
              for (dc in 0...2)
                {
                  var col = bc + dc;
                  var row = br + dr;
                  if (SewerModel.isFloor(m, col, row))
                    cells.push({ col: col, row: row });
                }
            if (cells.length == 0)
              continue;
            var cell = cells[(hh >> 7) % cells.length];
            // per-cell rate held constant however many cells the block offered, halved in rooms —
            // SewerGround.scatter's gate
            var pct = SewerStyle.POOL_PCT * cells.length;
            if (m.room[cell.row][cell.col])
              pct = Std.int(pct / 2);
            if (hh % 100 >= pct ||
                SewerProps.nearExit(m, cell.col, cell.row))
              continue;
            var cx = cell.col * CELL - half + CELL / 2;
            var cz = cell.row * CELL - half + CELL / 2;
            // clear of every lamp pool: two overlapping translucent pools double-darken where they meet
            var clear = true;
            for (i in 0...lampPools)
              if (Math.abs(pools[i].x - cx) < 2 * CELL &&
                  Math.abs(pools[i].z - cz) < 2 * CELL)
                clear = false;
            if (!clear)
              continue;
            var h2 = SewerModel.mix(hh ^ 0x2545F491);
            var size = SewerStyle.POOL_MIN + ((h2 >> 3) % 1000) / 1000.0 * (SewerStyle.POOL_MAX - SewerStyle.POOL_MIN);
            place(m, pools, cx + ((h2 >> 13) % 100 / 100.0 - 0.5) * CELL * 0.5,
              cz + ((h2 >> 20) % 100 / 100.0 - 0.5) * CELL * 0.5, size, hh);
          }
      return {
        pools: pools,
      };
    }

// one pool at (cx,cz), shrunk until its rotated footprint lies on floor cells only; dropped if
// even POOL_MIN does not fit. the cell and the yaw come off the hash, the aspect off the atlas cell
  static function place(m:Sewer, pools:Array<SewerPool>, cx:Float, cz:Float, size:Float, hh:Int):Void
    {
      var R = SewerStyle.POOL_RECTS;
      var cell = (hh >> 9) % R.length;
      var r = R[cell];
      var aspect = (r[1] - r[3]) / (r[2] - r[0]);
      var ang = ((hh >> 17) % 1024) / 1024.0 * Math.PI * 2;
      var ca = Math.abs(Math.cos(ang));
      var sa = Math.abs(Math.sin(ang));
      while (size >= SewerStyle.POOL_MIN)
        {
          var w = size;
          var d = size * aspect;
          if (fits(m, cx, cz, w * ca + d * sa, w * sa + d * ca))
            {
              pools.push({
                x: cx,
                z: cz,
                w: w,
                d: d,
                ang: ang,
                cell: cell,
              });
              return;
            }
          size *= 0.85;
        }
    }

// does an ex x ez box centred at (cx,cz), grown by POOL_MARGIN, cover floor cells only?
  static function fits(m:Sewer, cx:Float, cz:Float, ex:Float, ez:Float):Bool
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var g = SewerStyle.POOL_MARGIN;
      var c0 = Math.floor((cx - ex / 2 - g + half) / CELL);
      var c1 = Math.floor((cx + ex / 2 + g + half) / CELL);
      var r0 = Math.floor((cz - ez / 2 - g + half) / CELL);
      var r1 = Math.floor((cz + ez / 2 + g + half) / CELL);
      for (row in r0...r1 + 1)
        for (col in c0...c1 + 1)
          if (!SewerModel.isFloor(m, col, row))
            return false;
      return true;
    }

// one top-down quad for a pool, corners in SewerGround.top's order (so the normal comes out +Y),
// uv the 8 floats of its atlas rect
  static function quad(b:MeshBuf, p:SewerPool, uv:Array<Float>):Void
    {
      var hx = p.w / 2;
      var hz = p.d / 2;
      var ca = Math.cos(p.ang);
      var sa = Math.sin(p.ang);
      var y = SewerStyle.POOL_Y;
      inline function pt(ox:Float, oz:Float):Array<Float>
        return [p.x + ox * ca - oz * sa, y, p.z + ox * sa + oz * ca];
      MeshBufTools.quad(b, pt(-hx, hz), pt(hx, hz), pt(hx, -hz), pt(-hx, -hz), uv);
    }
}
