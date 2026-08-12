package render.sewer;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.sewer.SewerModel.Sewer;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// dressing for the two HORIZONTAL surfaces of a tunnel: the ledge plateau the overhead camera looks
// down on, and the walkway floor. the vertical twin is render.sewer.SewerDetail, which owns the wall
// face (grime band, contact shadows, wall decals); the split mirrors the city's WallDecals vs
// roofs/RoofDetails. everything here is derived from the cell grid, deterministic, persisted nowhere.
//
// this is where the screen area actually is. measured on the habitat at WALL_H 3.0: wall FACES cover
// 0.67% of the 3D view, ledge TOPS 14.68% — 22x more — and the floor takes most of the rest
class SewerGround
{
  static inline var CELL = CityConfig.CELL;

// all horizontal-surface dressing into the scene
  public static function build(scene:Scene, m:Sewer):Void
    {
      // ledge-top clutter: what would realistically sit on top of a tunnel wall, or fall onto it.
      // the pipe run is off (see SewerStyle). nothing crosses a cell edge up here — most of a tunnel
      // wall is one cell wide, so any spill goes over the drop
      scatter(scene, m, {
        types: [
          { tex: SewerStyle.TOP_VALVE, w: 1.8, d: 1.8, alpha: 1.0, organic: false },
          { tex: SewerStyle.TOP_RUBBLE, w: 2.4, d: 2.0, alpha: 1.0, organic: true },
          // half the moss it was: at 2.6 x 2.2 the patch filled its cell and read as a tile swap
          { tex: SewerStyle.TOP_MOSS, w: 1.3, d: 1.1, alpha: 1.0, organic: true },
        ],
        pct: SewerStyle.LEDGE_PCT,
        y: SewerStyle.WALL_H + SewerStyle.LEDGE_DECAL_Y,
        margin: SewerStyle.LEDGE_MARGIN,
        solid: true,
        cross: false,
      });
      // floor decals: standing water and the drains it should be going down. the two puddles and the
      // stain keep an opacity below 1 — unlike the props, shallow water genuinely IS see-through,
      // and letting the walkway read through it is what stops it looking like a pit
      scatter(scene, m, {
        types: [
          { tex: SewerStyle.FLOOR_PUDDLE, w: 2.8, d: 2.2, alpha: 0.3, organic: true },
          { tex: SewerStyle.FLOOR_PUDDLE_2, w: 1.8, d: 1.6, alpha: 0.35, organic: true },
          { tex: SewerStyle.FLOOR_GRATE, w: 1.6, d: 1.6, alpha: 1.0, organic: false },
          { tex: SewerStyle.FLOOR_STAIN, w: 2.6, d: 2.0, alpha: 0.8, organic: true },
        ],
        pct: SewerStyle.FLOOR_PCT,
        y: SewerStyle.FLOOR_DECAL_Y,
        margin: SewerStyle.FLOOR_MARGIN,
        solid: false,
        cross: true,
      });
    }

// ---------------------------------------------------------------------------------------------
// hash-placed top-down quads over one of the two horizontal surfaces, merged per image. the
// placement discipline is render.world.WallDecals' and the idea is roofs/RoofDetails', but neither
// could be reused as-is: WallDecals emits onto vertical faces, and RoofDetails derives sectors from
// a building footprint and instances PER BUILDING because Occlusion fades each with its own.
// underground there is no occlusion pass, so every quad of one image merges into a single mesh —
// one draw call per image no matter how big the level is.
//
// placement is per 2x2 BLOCK, not per cell, which is RoofDetails' sector idea in miniature. an
// independent per-cell coin flip is what an even scatter is NOT: at 22% it deals runs of five and
// six adjacent props often enough to be seen, and they read as a deliberate line. one prop per block
// caps a run at two by construction (only where two neighbouring blocks both pick their touching
// cell). the gate multiplies by however many cells the block actually offers, so a one-cell-wide
// wall — most of a tunnel — comes out at the same per-cell density as an open plateau.
//
// deterministic: every decision comes from the block's own coordinates through SewerModel.mix, so a
// tunnel is dressed identically on every reload and nothing is persisted
  static function scatter(scene:Scene, m:Sewer, o:SewerScatterOpts):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var bufs = [for (_ in o.types) MeshBufTools.make()];
      for (brow in 0...Std.int((m.h + 1) / 2))
        for (bcol in 0...Std.int((m.w + 1) / 2))
          {
            var bc = bcol * 2;
            var br = brow * 2;
            // distinct multipliers per surface so the ledge and the floor of the same column do not
            // decide together, and neither correlates with SewerDetail's wall-face roll
            var hh = SewerModel.mix(o.solid ? (bc * 40503) ^ (br * 92821) : (bc * 68917) ^ (br * 40503));
            // which cells of this block can take a decal at all
            var cells = [];
            for (dr in 0...2)
              for (dc in 0...2)
                {
                  var col = bc + dc;
                  var row = br + dr;
                  if (col >= m.w ||
                      row >= m.h ||
                      m.floor[row][col] == o.solid)
                    continue;
                  cells.push({ col: col, row: row });
                }
            if (cells.length == 0)
              continue;
            var cell = cells[(hh >> 7) % cells.length];
            // per-CELL rate held constant however many cells the block offered. generator rooms are
            // kept tidier than the tunnels — the same split render.sewer.Debris uses for its litter.
            // a pct above 25 saturates this gate, which is the point at which a block grid stops
            // being able to express the density and the rate should go back to per-cell
            var pct = o.pct * cells.length;
            if (!o.solid &&
                m.room[cell.row][cell.col])
              pct = Std.int(pct / 2);
            if (hh % 100 >= pct)
              continue;
            // three mixed words: hh decides, h2 sizes, h3 offsets. one 31-bit word cannot feed all
            // eight fields without overlapping slices, and overlapping slices couple size to offset
            var h2 = SewerModel.mix(hh ^ 0x2545F491);
            var h3 = SewerModel.mix(h2);
            var ti = (hh >> 13) % o.types.length;
            var t = o.types[ti];
            var ang = t.organic ? ((hh >> 17) % 1024) / 1024.0 * Math.PI * 2 : 0.0;
            // an organic decal may spill ACROSS a cell edge — a puddle that stops dead on every
            // 4-unit boundary is what gives the grid away. only when the whole 3x3 around the cell
            // is the same surface, so it never creeps under a wall or over the ledge drop
            var span = CELL - 2 * o.margin;
            if (o.cross &&
                t.organic &&
                open3x3(m, cell.col, cell.row, o.solid))
              span = 2 * CELL - 2 * o.margin;
            var sw = jitter(h2, t.organic);
            var w = t.w * sw;
            var d = t.d * (t.organic ? jitter(h2 >> 11, true) : sw);
            // the ROTATED footprint is what has to fit the cell, or a turned puddle spills over the
            // ledge edge. shrink both axes by one factor so the shape is preserved
            var ca = Math.cos(ang);
            var sa = Math.sin(ang);
            var ex = Math.abs(w * ca) + Math.abs(d * sa);
            var ez = Math.abs(w * sa) + Math.abs(d * ca);
            var fit = 1.0;
            if (ex > span)
              fit = span / ex;
            if (ez > span &&
                span / ez < fit)
              fit = span / ez;
            w *= fit;
            d *= fit;
            ex *= fit;
            ez *= fit;
            var cx = cell.col * CELL - half + CELL / 2 + ((h3 % 1000) / 1000.0 - 0.5) * (span - ex);
            var cz = cell.row * CELL - half + CELL / 2 + (((h3 >> 12) % 1000) / 1000.0 - 0.5) * (span - ez);
            top(bufs[ti], cx, cz, w, d, o.y, ang);
          }
      for (i in 0...o.types.length)
        {
          if (bufs[i].idx.length == 0)
            continue;
          var geo = new BufferGeometry();
          geo.setAttribute('position', new Float32BufferAttribute(bufs[i].pos, 3));
          geo.setAttribute('uv', new Float32BufferAttribute(bufs[i].uv, 2));
          geo.setIndex(bufs[i].idx);
          geo.computeVertexNormals();
          // same recipe as SewerDetail's wall decals. no tint: unlike the chalky wall seepage, this
          // art is authored against the surface it lands on (rose-brown cap, pale grey-green floor)
          var mesh = new Mesh(geo, new MeshLambertMaterial({
            map: Textures.loadTexture(o.types[i].tex, 'roof'),
            transparent: true,
            opacity: o.types[i].alpha,
            // three cuts on opacity * texel alpha, so scaling the threshold by the same opacity
            // keeps the cut at one texel-alpha value however see-through the type is
            alphaTest: 0.35 * o.types[i].alpha,
            depthWrite: false,
            side: THREE.FrontSide,
            polygonOffset: true,
            polygonOffsetFactor: -2,
            polygonOffsetUnits: -2,
          }));
          mesh.receiveShadow = true;
          scene.add(mesh);
        }
    }

// is the whole 3x3 around this cell the surface this pass dresses? (isFloor is bounds-safe, and
// reads outside the grid as solid, which is what the always-solid area border is)
  static function open3x3(m:Sewer, col:Int, row:Int, solid:Bool):Bool
    {
      for (dr in -1...2)
        for (dc in -1...2)
          if (SewerModel.isFloor(m, col + dc, row + dr) == solid)
            return false;
      return true;
    }

// scale factor off hash bits: an organic thing stretches widely and per axis, a manufactured part
// only varies a little and keeps its aspect
  static inline function jitter(h:Int, organic:Bool):Float
    {
      var f = (h % 1000) / 1000.0;
      return organic ? 0.70 + f * 0.65 : 0.85 + f * 0.30;
    }

// one flat top-down quad centred at (cx,cz), w x d world units, at height y, turned `ang` about the
// vertical. corner order matches SewerGeom.flat, and rotation preserves winding, so the computed
// normal still comes out at +Y
  static function top(b:MeshBuf, cx:Float, cz:Float, w:Float, d:Float, y:Float, ang:Float):Void
    {
      var hx = w / 2;
      var hz = d / 2;
      var ca = Math.cos(ang);
      var sa = Math.sin(ang);
      inline function px(ox:Float, oz:Float):Float
        return cx + ox * ca - oz * sa;
      inline function pz(ox:Float, oz:Float):Float
        return cz + ox * sa + oz * ca;
      MeshBufTools.quad(b,
        [px(-hx, hz), y, pz(-hx, hz)],
        [px(hx, hz), y, pz(hx, hz)],
        [px(hx, -hz), y, pz(hx, -hz)],
        [px(-hx, -hz), y, pz(-hx, -hz)],
        [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0]);
    }
}
