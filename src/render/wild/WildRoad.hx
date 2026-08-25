package render.wild;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.Poly.tag;
import render.wild.WildModel.Wild;

// the highway surface: asphalt over the corridor cells, and a dashed centre line down the middle.
//
// render.wild.WildPatches is the template and the differences are the interesting part:
//  - ALPHA-CUT, but not the way render.world.CoverageMask cuts a patch layer. that one hands the art
//    a smooth radial field and lets the ART's own alpha do the raggedness; asphalt is an opaque tile
//    with no alpha at all, so the same trick here would cut a clean iso-contour — which, across a
//    strip, is the straight line being fixed. so the shape is baked INTO the mask instead (edgeMask),
//    which is also what render.Textures.loadRampTexture and render.sewer.SewerDetail.grime each
//    concluded after failing with a distance-only ramp. it is not opaque and it does not dissolve:
//    alphaTest gives a hard edge that happens to be shaped like a broken one.
//  - the asphalt sits ABOVE both patch layers and WildPatches skips the corridor cells, so the two
//    never argue over the same ground.
//  - the ground under it is already FLAT: render.wild.WildHeight grades the corridor before any of
//    this is built, so the ribbon has no crosswise relief to fight and its shoulder meets real land.
//
// like the patches it is still SUBDIVIDED to WildStyle.SUB and emitted per render.Chunks.CELLS block.
// the subdivision is not optional even on a graded corridor — the road follows the land ALONG its
// length, so a cell-sized quad would still chord over that
class WildRoad
{
  static inline var CELL = CityConfig.CELL;

// emit the asphalt and the centre line. a no-op where no highway crosses this area, which is most of
// them — the region map runs one trunk and one branch over a whole region
  public static function build(scene:Scene, m:Wild, areaID:Int):Void
    {
      if (m.road == null)
        return;
      // the VERGE first and underneath. that order is the point of stacking the two rather than
      // abutting them: a bay the asphalt's mask bites out then exposes shoulder dirt instead of clean
      // turf, which is what a broken road edge looks like — and it costs nothing, because the asphalt
      // hides whatever reaches under it anyway
      ribbon(scene, m, areaID, {
        tex: WildStyle.VERGE,
        tile: WildStyle.VERGE_TILE,
        y: WildStyle.VERGE_Y,
        order: render.particles.Sprites.ORD_DECAL - 0.6,
        halfW: WildStyle.VERGE_HALF * CELL,
        reach: WildStyle.VERGE_HALF + WildStyle.VERGE_MARGIN,
        rMin: WildStyle.VERGE_R_MIN,
        rMax: WildStyle.VERGE_R_MAX,
        step: WildStyle.VERGE_STEP,
        along: WildStyle.VERGE_MASK_ALONG,
        across: WildStyle.VERGE_MASK_ACROSS,
        salt: 1597334677,
        cls: 'wild-verge',
        label: 'wilderness highway verge',
      });
      ribbon(scene, m, areaID, {
        tex: WildStyle.ROAD,
        tile: WildStyle.ROAD_TILE,
        y: WildStyle.ROAD_Y,
        order: render.particles.Sprites.ORD_DECAL - 0.5,
        halfW: m.road.half * CELL,
        reach: m.road.half + WildStyle.ROAD_EDGE_MARGIN,
        rMin: WildStyle.ROAD_EDGE_R_MIN,
        rMax: WildStyle.ROAD_EDGE_R_MAX,
        step: WildStyle.ROAD_EDGE_STEP,
        along: WildStyle.ROAD_MASK_ALONG,
        across: WildStyle.ROAD_MASK_ACROSS,
        // a DIFFERENT salt from the verge's, or the two edges crumble in lockstep and every bay in
        // the asphalt has a matching bay in the shoulder two units outside it
        salt: 990424547,
        cls: 'wild-road',
        label: 'wilderness highway',
      });
      dashes(scene, m);
    }

// one alpha-cut ribbon: its material, its mask and its mesh
  static function ribbon(scene:Scene, m:Wild, areaID:Int, o:RibbonOpts):Void
    {
      var mat = render.world.VisionMask.patch(tag(new MeshLambertMaterial({
        map: Textures.loadTexture(o.tex, 'asphalt', 1),
        side: THREE.FrontSide,
        // the edge lives HERE and not in the vertices — see WildStyle.ROAD_EDGE_MARGIN
        alphaMap: edgeMask(m, areaID, o),
        alphaTest: WildStyle.ROAD_ALPHA_TEST,
      }),
        o.cls, o.label, o.tex));
      // AFTER the patch, never in the literal above — see WildStyle.ROAD_ALPHA_TEST. patch() reads
      // `transparent` to choose which vision-mask branch it compiles in, and this material wants the
      // ground branch while still blending its own edge
      mat.transparent = true;
      surface(scene, mat, m, o);
    }

// bake the asphalt's alpha cutout: white where the road is material, black where it is not.
//
// the shape comes from STAMPS, not from a function of the along-coordinate, and that is the whole
// point of moving off geometry (WildStyle.ROAD_EDGE_MARGIN carries the argument). a circle centred on
// the nominal edge line leaves a spur if it is white and bites a bay if it is black; two whites
// overlapping outside merge into a slab; one pushed clear lands as an island. none of those is a
// single offset per along-coordinate, so none of them can read as a wave.
//
// the canvas is oriented to the corridor: its long axis is the road's own, so the texel budget goes
// down the edge instead of over 400 units of area the road never touches. that costs one swap here
// and one in the uv transform below, because the mesh's uv is world xz on both axes whichever way the
// corridor runs. flipY = false for render.world.CoverageMask's reason: canvas row 0 is the low end of
// its axis, and a bare CanvasTexture mirrors it.
//
// seeded off the AREA ID, so the crumble is stable across reloads and rebuilds and differs from the
// next area's — the corridor rect alone would not do, since every area on one trunk shares it
  static function edgeMask(m:Wild, areaID:Int, o:RibbonOpts):Texture
    {
      var full = CityConfig.GRID * CELL;
      var halfW = o.halfW;
      var wd = o.reach * CELL * 2;
      var pxA = o.along / full;
      var pxC = o.across / wd;
      var cv = js.Browser.document.createCanvasElement();
      cv.width = (m.road.alongX ? o.along : o.across);
      cv.height = (m.road.alongX ? o.across : o.along);
      var ctx = cv.getContext2d();
      ctx.fillStyle = '#000000';
      ctx.fillRect(0, 0, cv.width, cv.height);
      // from here everything is drawn in WORLD units: `a` runs 0..full down the corridor and `c` runs
      // 0..wd across it, and the transform puts them on whichever canvas axis this road uses. a circle
      // drawn under it is an ellipse in texels and a true circle in the world, which is what keeps the
      // crumble isotropic on a texture whose two axes are at different scales
      if (m.road.alongX)
        ctx.setTransform(pxA, 0, 0, pxC, 0, 0);
      else
        ctx.setTransform(0, pxA, pxC, 0, 0, 0);
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, wd / 2 - halfW, full, halfW * 2);
      var h = WildModel.mix(areaID * o.salt);
      var a = 0.0;
      while (a < full)
        {
          for (k in 0...2)
            {
              // ONE FRESH MIX PER QUANTITY, never bit-windows of a single draw. WildModel.mix returns
              // `x & 0x7fffffff`, i.e. 31 bits, so `h >> 24` leaves 0..127 — and the first pass tested
              // that window against ROAD_EDGE_SPUR * 1000 = 120, which is true 94% of the time. every
              // stamp came back a spur: forced white, pushed outward, and the mask baked a solid white
              // halo OUTSIDE the road with a black ring on the nominal edge, the exact inverse of a
              // crumbled edge. same too-close-to-its-own-threshold class the litter alpha and the
              // guard-rail reference are already logged under, and cheap to avoid outright
              h = WildModel.mix(h);
              var r = o.rMin + roll(h) / 1000.0 * (o.rMax - o.rMin);
              h = WildModel.mix(h);
              var white = (roll(h) < 500);
              h = WildModel.mix(h);
              // centred on the edge and jittered by its own radius, so the stamp always straddles it
              var jit = (roll(h) / 1000.0 - 0.5) * 2 * r;
              h = WildModel.mix(h);
              var spur = (roll(h) < WildStyle.ROAD_EDGE_SPUR * 1000);
              h = WildModel.mix(h);
              // the along position is jittered too: on the bare step this is a lattice, and a lattice
              // of blobs is the pattern the sines were replaced for
              var along = a + roll(h) / 1000.0 * o.step;
              var out = (k == 0 ? -1.0 : 1.0);
              if (spur)
                {
                  white = true;
                  jit = out * r * WildStyle.ROAD_EDGE_SPUR_PUSH;
                }
              // a SOFT-RIMMED stamp: solid to (1 - ROAD_EDGE_SOFT) of its radius, then ramping to
              // fully transparent at the rim, so a white one fades the asphalt out and a black one
              // fades it away rather than punching. the gradient is built in the same drawing space
              // as the arc, so the transform makes it a true circle in the world like the path
              var cz = wd / 2 + out * halfW + jit;
              var g = ctx.createRadialGradient(along, cz, r * (1 - WildStyle.ROAD_EDGE_SOFT),
                along, cz, r);
              g.addColorStop(0, (white ? 'rgba(255,255,255,1)' : 'rgba(0,0,0,1)'));
              g.addColorStop(1, (white ? 'rgba(255,255,255,0)' : 'rgba(0,0,0,0)'));
              ctx.fillStyle = g;
              ctx.beginPath();
              ctx.arc(along, cz, r, 0, Math.PI * 2);
              ctx.fill();
            }
          a += o.step;
        }
      var tex = new CanvasTexture(cv);
      tex.flipY = false;
      // the mesh's uv is (x, z) / ROAD_TILE on both axes, so the alphaMap's own transform has to undo
      // that tile and re-map: the corridor's axis onto 0..1 over the area rect, the other onto 0..1
      // over the mask band, offset so the band is centred on the centreline
      var sa = o.tile / full;
      var sc = o.tile / wd;
      var oc = 0.5 - (m.road.centre * CELL - full / 2) / wd;
      if (m.road.alongX)
        {
          tex.repeat.set(sa, sc);
          tex.offset.set(0.5, oc);
        }
      else
        {
          tex.repeat.set(sc, sa);
          tex.offset.set(oc, 0.5);
        }
      tex.needsUpdate = true;
      return tex;
    }

// the asphalt, as ONE mesh at the scene root — the same call the dashes take, and the opposite of the
// one render.wild.WildPatches makes next door.
//
// a patch LAYER chunks because it spans the whole area, so a single mesh would submit the area's
// entire blended fill every frame however little of it is on screen. a road is a STRIP: three cells
// wide over a hundred long is ~3% of the area, which at SUB 2 is about 2,200 triangles of nearly no
// fill. chunking it bought nothing and cost a draw call per block the corridor crossed — measured at
// TWELVE on a 90-cell mountain area, against one here
  static function surface(scene:Scene, mat:MeshLambertMaterial, m:Wild, o:RibbonOpts):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var S = WildStyle.SUB;
      var step = CELL / S;
      var pos = [];
      var nor = [];
      var uv = [];
      var idx = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            // the ribbon's REACH and not the road cells: the mesh runs past the tiles the generator
            // stamped, because the alpha mask carves the edge out of it and needs material on both
            // sides of the nominal line to carve. what the mask leaves outside is a spur, what it
            // takes inside is a bay.
            //
            // tested against the cell's NEAR EDGE (distTo - 0.5), not its centre. that is not a
            // rounding nicety: distTo comes back an INTEGER for a 3-cell corridor, so the centre test
            // this replaced dropped whichever ring sat exactly on the reach — which for the asphalt
            // was every ring, and its apron was silently zero cells wide for a full release
            if (distTo(m, col, row) - 0.5 >= o.reach)
              continue;
            var cx = col * CELL - half;
            var cz = row * CELL - half;
            for (sj in 0...S)
              for (si in 0...S)
                {
                  var x0 = cx + si * step;
                  var z0 = cz + sj * step;
                  var x1 = x0 + step;
                  var z1 = z0 + step;
                  var base = Std.int(pos.length / 3);
                  for (p in [[x0, z0], [x1, z0], [x1, z1], [x0, z1]])
                    {
                      pos.push(p[0]);
                      pos.push(WildHeight.at(p[0], p[1]) + o.y);
                      pos.push(p[1]);
                      // the graded surface's own normal. flat across the ribbon, tilted along it —
                      // which is exactly what makes a road climbing a hill read as climbing it
                      WildHeight.pushNormal(nor, p[0], p[1]);
                      // uv off the world position on BOTH axes, so nothing stretches and the grain
                      // runs continuously from one end of the corridor to the other. the alpha mask
                      // rides this same uv with its own transform, which is why it can be fitted to
                      // the corridor instead of to the area
                      uv.push(p[0] / o.tile);
                      uv.push(p[1] / o.tile);
                    }
                  idx.push(base);
                  idx.push(base + 2);
                  idx.push(base + 1);
                  idx.push(base);
                  idx.push(base + 3);
                  idx.push(base + 2);
                }
          }
      if (idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geo.setAttribute('normal', new Float32BufferAttribute(nor, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
      geo.setIndex(idx);
      var mesh = new Mesh(geo, mat);
      // between the patch overlays (ORD_DECAL - 1) and the decals (ORD_DECAL), and the fractional
      // steps are needed rather than tidy: blending puts these materials in the TRANSPARENT queue
      // alongside the two patch layers, and at an equal renderOrder three falls back to a
      // back-to-front distance sort — which between near-coplanar ground layers is a coin toss that
      // flickers. FOUR layers share that queue out here now (earth, dead grass, verge, asphalt) and
      // every one of them needs its own number.
      // the centre line needs no such care: it is opaque, so it draws in the earlier queue entirely,
      // and it sits above this at ROAD_PAINT_Y, so its depth writes reject the asphalt behind it
      mesh.renderOrder = o.order;
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// the dashed centre line, as ONE mesh at the scene root rather than per chunk block.
//
// deliberate, and the opposite call to the asphalt beside it: WildPatches chunks because a layer that
// spans the area submits the area's whole blended FILL every frame however little is on screen, and
// that argument is about fill. a line of ~50 dashes 0.18 units wide is ~100 triangles of nearly no
// fill at all, so one draw call from anywhere beats a per-block split that can only ever cost more.
//
// the PATTERN is geometry and the WEAR is the texture, which is render.world.Ground's own split — the
// art is a field of worn paint with no shape in it. and like the city's it stays OPAQUE: the keyed
// scuff pixels then render as grey wear instead of cutout jaggies
  static function dashes(scene:Scene, m:Wild):Void
    {
      var mat = render.world.VisionMask.patch(tag(new MeshLambertMaterial({
        map: Textures.loadTexture(WildStyle.ROAD_PAINT, 'asphalt', 1),
        side: THREE.FrontSide,
      }),
        'wild-road-paint', 'wilderness highway centre line', WildStyle.ROAD_PAINT));
      var half = (CityConfig.GRID * CELL) / 2;
      var c = m.road.centre * CELL - half;
      var end = (m.road.alongX ? m.w : m.h) * CELL - half;
      var w2 = WildStyle.ROAD_LINE_W / 2;
      var pos = [];
      var nor = [];
      var uv = [];
      var idx = [];
      // the across-axis is MIRRORED for a north-south road, and it is not cosmetic: swapping which
      // world axis carries `along` reverses the triangle winding, so the same corner order that faces
      // +Y for an east-west road faces -Y for this one and FrontSide culls every dash. costs one sign
      var s = (m.road.alongX ? w2 : -w2);
      var a = -half;
      while (a < end)
        {
          var a1 = a + WildStyle.ROAD_DASH_LEN;
          if (a1 > end)
            a1 = end;
          var base = Std.int(pos.length / 3);
          // the four corners, laid out along the corridor axis and across it
          for (p in [[a, -s], [a1, -s], [a1, s], [a, s]])
            {
              var x = (m.road.alongX ? p[0] : c + p[1]);
              var z = (m.road.alongX ? c + p[1] : p[0]);
              pos.push(x);
              pos.push(WildHeight.at(x, z) + WildStyle.ROAD_PAINT_Y);
              pos.push(z);
              WildHeight.pushNormal(nor, x, z);
              uv.push(x / WildStyle.ROAD_PAINT_TILE);
              uv.push(z / WildStyle.ROAD_PAINT_TILE);
            }
          idx.push(base);
          idx.push(base + 2);
          idx.push(base + 1);
          idx.push(base);
          idx.push(base + 3);
          idx.push(base + 2);
          a += WildStyle.ROAD_DASH_LEN + WildStyle.ROAD_DASH_GAP;
        }
      if (idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geo.setAttribute('normal', new Float32BufferAttribute(nor, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
      geo.setIndex(idx);
      var mesh = new Mesh(geo, mat);
      mesh.renderOrder = render.particles.Sprites.ORD_DECAL - 1;
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// one hash draw as 0..999. trivial, and named so the edgeMask loop above cannot quietly go back to
// slicing bit windows out of a 31-bit value and testing them against per-mille thresholds
  static inline function roll(h:Int):Int
    {
      return h % 1000;
    }

// how far a WORLD point lies outside the asphalt's NOMINAL edge, in world units — negative under the
// ribbon, growing with distance from it. a large positive with no road at all, so a caller gating on
// "far enough from the highway" needs no null test of its own.
//
// NOMINAL is the word that matters. this is the straight line the generator stamped, and the visible
// edge is the alpha mask crumbling around it by up to ROAD_EDGE_MARGIN either way (see edgeMask).
// keeping the two apart is deliberate and is what stopped the alpha route being expensive: the grass
// fade, the pebble gate, the patch gate and the litter band all read this, and making any of them
// agree texel-for-texel with a baked mask would mean a CPU copy of the same stamps. instead each one
// is given slack — the grass thins over ROAD_GRASS_FADE cells, far wider than the crumble, and the
// patches reach ROAD_EDGE_R_MAX inside so a bay fills with dead grass instead of bare turf
  public static inline function edgeDist(m:Wild, x:Float, z:Float):Float
    {
      return offset(m, x, z) - m.road.half * CELL;
    }

// the same, measured off the VERGE's nominal outer edge — the dirt shoulder's boundary against the
// turf, and the one the grass, the pebbles and the ground patches all gate on now.
//
// they moved off edgeDist wholesale when the verge went in, and the reason is worth keeping: the
// asphalt is no longer the outermost thing the corridor puts on the ground, so gating on it grew
// grass and dead-grass patches straight down the middle of a bare dirt shoulder. the asphalt's own
// edge is still what edgeDist is for, and WildPatches still reaches inside it so a bay fills
  public static inline function vergeDist(m:Wild, x:Float, z:Float):Float
    {
      return offset(m, x, z) - WildStyle.VERGE_HALF * CELL;
    }

// perpendicular distance from a WORLD point to the corridor CENTRELINE, in world units. a huge
// number with no road at all, so both callers above stay positive-and-far and no gate needs a null
// test of its own
  static inline function offset(m:Wild, x:Float, z:Float):Float
    {
      if (m.road == null)
        return 1e9;
      var c = m.road.centre * CELL - (CityConfig.GRID * CELL) / 2;
      return Math.abs((m.road.alongX ? z : x) - c);
    }

// the arc an actor takes stepping over a guard rail, or 0 for a move that crosses none.
//
// the rail lines are not stored anywhere: they fall out of the corridor rect and WildStyle.RAIL_OFF,
// the same two numbers render.wild.WildProps.rails places the instances from, so the animation and
// the geometry cannot drift apart. that is also why the rail going up on BOTH shoulders simplified
// this — with one run there was a side to remember, and it was chosen inside the placement pass and
// thrown away.
//
// the test is a SIGN CHANGE across the line rather than a cell match, because the rail stands at a
// fractional offset (centre +/- half + 0.9) and so separates one specific pair of adjacent cells. a
// diagonal step counts once however render.ActorAnim.cornerBend routes the slide underneath it —
// there is one barrier under that move whichever leg crosses it
  public static function climbArc(m:Wild, fromCol:Int, fromRow:Int, toCol:Int, toRow:Int):Float
    {
      if (m.road == null)
        return 0.0;
      var a = (m.road.alongX ? fromRow : fromCol) + 0.5;
      var b = (m.road.alongX ? toRow : toCol) + 0.5;
      if (a == b)
        return 0.0;
      var off = m.road.half + WildStyle.RAIL_OFF;
      for (sgn in [-1.0, 1.0])
        {
          var line = m.road.centre + sgn * off;
          if ((a < line) != (b < line))
            return WildStyle.CLIMB_ARC;
        }
      return 0.0;
    }

// is this cell part of the corridor? the rect is exact rather than a re-scan of the tiles: `centre`
// and `half` came out of the road cells' own bounding box, so centre - half is the first road cell and
// centre + half is one past the last
  public static inline function isRoad(m:Wild, col:Int, row:Int):Bool
    {
      if (m.road == null)
        return false;
      var p = (m.road.alongX ? row : col);
      return p >= m.road.centre - m.road.half &&
        p < m.road.centre + m.road.half;
    }

// how far a cell sits from the corridor centreline, in CELLS, or -1 with no road. the shoulder props
// and the roadside litter both gate on this
  public static inline function distTo(m:Wild, col:Int, row:Int):Float
    {
      if (m.road == null)
        return -1;
      return Math.abs((m.road.alongX ? row : col) + 0.5 - m.road.centre);
    }
}
