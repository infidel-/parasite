package render.sewer;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.Textures;
import render.sewer.SewerModel.Sewer;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;
import render.world.PropShader.ShaderPatch;

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

// one spine point of a trickle
typedef SewerStreamPoint = {
  // world x
  x:Float,
  // world z
  z:Float,
  // half width here, world units (taper and jitter already applied)
  hw:Float,
  // opacity here: 0 at the very ends, 1 along the run
  a:Float,
};

// everything the water pass places, split from the build so a layout can be read without a scene —
// parasiteHx['render.sewer.SewerWater'].layout(SewerModel.demo())
typedef SewerWaterLayout = {
  // standing pools, the trickles' sinks among them
  pools:Array<SewerPool>,
  // trickles, each a spine from a wall foot to its pool
  streams:Array<Array<SewerStreamPoint>>,
};

// standing water on the walkway, and the trickles that feed it. the third attempt at water down
// here, and the first that is not darker albedo: the sludge gutter read as a dark stripe and the
// Lambert puddles as faint smears, because a Lambert surface under this much ambient can only say
// "water" by being darker, and darker reads as a pit. this is MeshStandardMaterial, so the overhead
// shafts and the wall brackets put a real sheen on it — the one thing that reads as liquid at this
// pitch — while its albedo sits at 0.85x the walkway's. a node lamp's mirror point lands toward the
// camera by bulbY / tan(pitch), ~4.2 units at the near pose and ~2.0 at the far one, so the lamp
// pools are pushed south off their lamp by LAMP_POOL_SOUTH to sit under it at both.
// a trickle starts under a SEEPAGE stain (SewerDetail.seepAt), so the stain runs down the wall and
// the water carries on across the floor into a pool; it is never a corridor-long centreline, which
// is what the gutter was. derived from the cell grid like every other sewer pass: deterministic,
// persisted nowhere
class SewerWater
{
  static inline var CELL = CityConfig.CELL;

  // the live trickle texture, whose offset tick() scrolls. the LAST build's, which is the real
  // level's: the warm scene is built first and thrown away
  static var flow:Texture = null;
  // the ripple clock in BASE_MS turns, and the knobs every water material shares. uniform objects
  // three keeps BY REFERENCE, so a live edit of .value reaches both meshes at once
  static var uTime = { value: 0.0 };
  static var uSmooth = { value: SewerStyle.WATER_SMOOTH };
  static var uRough = { value: SewerStyle.WATER_ROUGH };
  static var uSilt = { value: new Vector2(SewerStyle.WATER_SILT_LO, SewerStyle.WATER_SILT_HI) };
  static var uScum = { value: SewerStyle.WATER_SCUM };
  static var uTint = { value: new Color(SewerStyle.WATER_SPEC_TINT) };
  static var uCap = { value: SewerStyle.WATER_SPEC_CAP };

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
      // both meshes are built even when the level rolled nothing: the warm demo tunnel may well
      // roll none, and a mesh that is never added is a program that compiles on the first real
      // entry instead. an empty index range submits no draw call
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pools.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(pools.uv, 2));
      geo.setIndex(pools.idx);
      geo.computeVertexNormals();
      // nearly opaque on purpose: three multiplies the specular by the fragment alpha too, so the
      // 0.3 the old puddles ran at would have kept a third of the sheen. the albedo is what keeps
      // it from reading as a hole, not the blend
      var mesh = new Mesh(geo, VisionMask.patch(surface(new MeshStandardMaterial({
        map: Textures.loadTexture(SewerStyle.WATER_POOLS, 'roof'),
        roughness: SewerStyle.WATER_SMOOTH,
        metalness: 0.0,
        transparent: true,
        opacity: SewerStyle.POOL_ALPHA,
        alphaTest: 0.3,
        depthWrite: false,
        side: THREE.FrontSide,
        polygonOffset: true,
        polygonOffsetFactor: -2,
        polygonOffsetUnits: -2,
      }), SewerStyle.WATER_RIPPLE, SewerStyle.WATER_RATE)));
      mesh.receiveShadow = true;
      scene.add(mesh);

      // the trickles: one merged strip, the flowing swatch along it
      var pos:Array<Float> = [];
      var uv:Array<Float> = [];
      var col:Array<Float> = [];
      var idx:Array<Int> = [];
      for (s in lay.streams)
        strip(s, pos, uv, col, idx);
      var sgeo = new BufferGeometry();
      sgeo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      sgeo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
      sgeo.setAttribute('color', new Float32BufferAttribute(col, 4));
      sgeo.setIndex(idx);
      sgeo.computeVertexNormals();
      flow = Textures.loadTexture(SewerStyle.WATER_STREAM, 'roof');
      var smesh = new Mesh(sgeo, VisionMask.patch(surface(new MeshStandardMaterial({
        map: flow,
        roughness: SewerStyle.WATER_SMOOTH,
        metalness: 0.0,
        vertexColors: true, // rgb 1, alpha carries the soft edges and the two end fades
        transparent: true,
        opacity: SewerStyle.POOL_ALPHA,
        depthWrite: false,
        side: THREE.FrontSide,
        polygonOffset: true,
        polygonOffsetFactor: -3, // over the pool it runs into
        polygonOffsetUnits: -3,
      }), SewerStyle.STREAM_RIPPLE, SewerStyle.STREAM_RATE)));
      smesh.receiveShadow = true;
      scene.add(smesh);
    }

// scroll the trickles toward their pools (the map's own offset) and run the ripple clock
  public static function tick(dtMs:Float):Void
    {
      uTime.value += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      if (flow != null)
        flow.offset.x -= dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS * SewerStyle.STREAM_FLOW;
    }

// the water SURFACE, folded into a material before VisionMask.patch so the mask's hook chains over
// this one. a flat plane at one roughness drew the same smooth white disc on every pool, so three
// things change, all in the fragment shader:
//   ripples — four directional waves in WORLD xz (so every pool ripples at the same scale whatever
//             its size, which an atlas-uv normal map could not), gradient taken analytically, tilt
//             the shading normal. the glint breaks into broken streaks that crawl, and the tilt is
//             also what lets a smooth surface still FIND the glint: the mirror point of a bulb
//             wanders ~5 units with the camera, and a flat 0.1 surface missed a 4-unit pool more
//             often than not (why the first cut ran a uniform 0.4)
//   roughness — glassy on the water, matte on the silt rim (read off the albedo's luminance) and on
//             slow low-frequency SCUM patches, where the ripples also die down
//   highlight — tinted murky and passed through a soft knee on its peak channel, so a lamp straight
//             overhead stays a coloured glint instead of clipping to flat white
// `amp` is the ripple slope at full strength, `rate` the wave phase speed in radians per BASE_MS.
// `mat` is Dynamic for the reason PropShader.patch gives: the material externs declare no
// onBeforeCompile / customProgramCacheKey
  static function surface(mat:Dynamic, amp:Float, rate:Float):Dynamic
    {
      var uAmp = { value: amp };
      var uRate = { value: rate };
      mat.onBeforeCompile = function(shader:ShaderPatch, renderer:Dynamic)
        {
          shader.uniforms.waterTime = uTime;
          shader.uniforms.waterAmp = uAmp;
          shader.uniforms.waterRate = uRate;
          shader.uniforms.waterSmooth = uSmooth;
          shader.uniforms.waterRough = uRough;
          shader.uniforms.waterSilt = uSilt;
          shader.uniforms.waterScum = uScum;
          shader.uniforms.waterTint = uTint;
          shader.uniforms.waterCap = uCap;
          shader.vertexShader = 'varying vec2 vWaterXZ;\n' +
            StringTools.replace(shader.vertexShader, '#include <project_vertex>',
              '#include <project_vertex>\n' +
              '  vWaterXZ = ( modelMatrix * vec4( transformed, 1.0 ) ).xz;');
          var f = shader.fragmentShader;
          // after <normal_fragment_maps>: `normal` exists and <lights_physical_fragment>, which reads
          // roughnessFactor, has not run yet — one anchor serves both
          f = StringTools.replace(f, '#include <normal_fragment_maps>',
            '#include <normal_fragment_maps>\n' +
            '  {\n' +
            '  vec2 wp = vWaterXZ;\n' +
            '  float wt = waterTime * waterRate;\n' +
            // 1 = open rippling water, 0 = a still scum patch. drifts slower than the waves
            '  float wCalm = waterNoise( wp * 0.45 + vec2( wt * 0.07, -wt * 0.05 ) );\n' +
            // a·k·cos(k d·p + s t)·d per wave; wavelengths 0.9..2.3 units at unrelated angles so the
            // sum never settles into a visible plaid
            '  vec2 wg = waterWave( wp, vec2( 0.80, 0.60 ), 2.7, 1.00, wt * 1.3 ) +\n' +
            '    waterWave( wp, vec2( -0.47, 0.88 ), 3.9, 0.70, -wt * 1.9 ) +\n' +
            '    waterWave( wp, vec2( 0.96, -0.28 ), 5.3, 0.50, wt * 2.3 ) +\n' +
            '    waterWave( wp, vec2( -0.60, -0.80 ), 7.1, 0.35, -wt * 2.9 );\n' +
            // 5.3 ~ half the summed a·k, so a typical slope lands near waterAmp
            '  vec2 wSlope = wg * waterAmp / 5.3 * mix( 0.25, 1.0, wCalm );\n' +
            '  normal = normalize( ( viewMatrix * vec4( normalize( vec3( -wSlope.x, 1.0, -wSlope.y ) ), 0.0 ) ).xyz );\n' +
            '  float wSilt = smoothstep( waterSilt.x, waterSilt.y,\n' +
            '    dot( diffuseColor.rgb, vec3( 0.2126, 0.7152, 0.0722 ) ) );\n' +
            '  roughnessFactor = mix( waterSmooth, waterRough, max( wSilt, ( 1.0 - wCalm ) * waterScum ) );\n' +
            '  }');
          // a Reinhard knee on the peak channel: asymptotic to waterCap, so no plateau of flat
          // colour, and hue-preserving where a per-channel clamp would bleach it
          f = StringTools.replace(f, '#include <lights_fragment_end>',
            '#include <lights_fragment_end>\n' +
            '  {\n' +
            '  vec3 wS = reflectedLight.directSpecular * waterTint;\n' +
            '  reflectedLight.directSpecular = wS / ( 1.0 + max( wS.r, max( wS.g, wS.b ) ) / waterCap );\n' +
            '  }');
          shader.fragmentShader = 'uniform float waterTime;\n' +
            'uniform float waterAmp;\n' +
            'uniform float waterRate;\n' +
            'uniform float waterSmooth;\n' +
            'uniform float waterRough;\n' +
            'uniform vec2 waterSilt;\n' +
            'uniform float waterScum;\n' +
            'uniform vec3 waterTint;\n' +
            'uniform float waterCap;\n' +
            'varying vec2 vWaterXZ;\n' +
            'float waterHash( vec2 p ) { return fract( sin( dot( p, vec2( 127.1, 311.7 ) ) ) * 43758.5453 ); }\n' +
            'float waterNoise( vec2 p )\n' +
            '{\n' +
            '  vec2 i = floor( p );\n' +
            '  vec2 u = fract( p );\n' +
            '  u = u * u * ( 3.0 - 2.0 * u );\n' +
            '  return mix( mix( waterHash( i ), waterHash( i + vec2( 1.0, 0.0 ) ), u.x ),\n' +
            '    mix( waterHash( i + vec2( 0.0, 1.0 ) ), waterHash( i + vec2( 1.0, 1.0 ) ), u.x ), u.y );\n' +
            '}\n' +
            'vec2 waterWave( vec2 p, vec2 d, float k, float a, float ph )\n' +
            '{\n' +
            '  return a * k * cos( k * dot( d, p ) + ph ) * d;\n' +
            '}\n' +
            f;
        };
      // three keys programs on base params, not on the hook: without a key of its own this program
      // could be handed to a plain Standard material. VisionMask.patch chains this key into its own
      mat.customProgramCacheKey = function()
        return 'sewerWater';
      return mat;
    }

// where every pool and trickle goes. three sources, each kept clear of the ones before it: a pool
// under most corridor-node lamps (where the sheen is), a trickle off some seepage stains with a
// pool at its end, and a sparse per-2x2-block scatter for the rest of the walkway
  public static function layout(m:Sewer):SewerWaterLayout
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var pools:Array<SewerPool> = [];
      var streams:Array<Array<SewerStreamPoint>> = [];
      // is (cx,cz) clear of every pool placed so far? two overlapping translucent pools
      // double-darken where they meet
      function clear(cx:Float, cz:Float):Bool
        {
          for (p in pools)
            if (Math.abs(p.x - cx) < 2 * CELL &&
                Math.abs(p.z - cz) < 2 * CELL)
              return false;
          return true;
        }
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
      // trickles: north, west and east walls only. a south wall stands between the camera and its
      // own foot (SewerProps.CAM_DIR), so a trickle off it would start out of sight
      for (row in 0...m.h)
        for (col in 0...m.w)
          for (dir in [0, 2, 3])
            {
              var off = SewerDetail.seepAt(m, col, row, dir);
              if (off == null ||
                  SewerProps.nearExit(m, col, row))
                continue;
              var hh = SewerModel.mix((col * 50331653) ^ (row * 25165843) ^ (dir * 12582917));
              if (hh % 100 >= SewerStyle.STREAM_PCT)
                continue;
              var s = stream(m, col, row, dir, off, hh, clear);
              if (s == null)
                continue;
              // the sink first: no pool, no trickle — water running into the floor and stopping
              // reads as a painted stripe
              var end = s[s.length - 1];
              var fx = dir == 0 ? 0.0 : (dir == 2 ? 1.0 : -1.0);
              var fz = dir == 0 ? 1.0 : 0.0;
              var r = SewerStyle.STREAM_POOL * 0.3;
              if (!place(m, pools, end.x + fx * r, end.z + fz * r, SewerStyle.STREAM_POOL, hh >> 3))
                continue;
              streams.push(s);
            }
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
                  var c = bc + dc;
                  var r = br + dr;
                  if (SewerModel.isFloor(m, c, r))
                    cells.push({ col: c, row: r });
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
            if (!clear(cx, cz))
              continue;
            var h2 = SewerModel.mix(hh ^ 0x2545F491);
            var size = SewerStyle.POOL_MIN + ((h2 >> 3) % 1000) / 1000.0 * (SewerStyle.POOL_MAX - SewerStyle.POOL_MIN);
            place(m, pools, cx + ((h2 >> 13) % 100 / 100.0 - 0.5) * CELL * 0.5,
              cz + ((h2 >> 20) % 100 / 100.0 - 0.5) * CELL * 0.5, size, hh);
          }
      return {
        pools: pools,
        streams: streams,
      };
    }

// one trickle's spine, out from the foot of wall face `dir` of (col,row) at the stain's lateral
// offset, or null where it cannot run: too short a floor run ahead, a point off the walkway, or
// its pool would land on one already placed. the meander is a hash random walk, so it is the same
// trickle every reload
  static function stream(m:Sewer, col:Int, row:Int, dir:Int, off:Float, hh:Int,
    clear:Float->Float->Bool):Array<SewerStreamPoint>
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      // flow direction (into the cell, away from the wall) and the source point at the wall foot
      var fx = dir == 0 ? 0.0 : (dir == 2 ? 1.0 : -1.0);
      var fz = dir == 0 ? 1.0 : 0.0;
      var sx = dir == 0 ? x0 + CELL / 2 + off : (dir == 2 ? x0 : x0 + CELL);
      var sz = dir == 0 ? z0 : z0 + CELL / 2 + off;
      // free floor straight ahead, in whole cells, and the run the trickle may take of it: it has
      // to stop a pool short of the far wall
      var run = 0;
      while (SewerModel.isFloor(m, col + Std.int(fx) * (run + 1), row + Std.int(fz) * (run + 1)))
        run++;
      var len = SewerStyle.STREAM_MIN + ((hh >> 7) % 1000) / 1000.0 * (SewerStyle.STREAM_MAX - SewerStyle.STREAM_MIN);
      var room = (run + 1) * CELL - SewerStyle.STREAM_POOL;
      if (len > room)
        len = room;
      if (len < SewerStyle.STREAM_MIN ||
          !clear(sx + fx * len, sz + fz * len))
        return null;
      // lateral axis, perpendicular to the flow
      var lx = -fz;
      var lz = fx;
      var n = Math.ceil(len / SewerStyle.STREAM_STEP);
      var pts:Array<SewerStreamPoint> = [];
      var wander = 0.0;
      var h = hh;
      for (i in 0...n + 1)
        {
          var t = i / n;
          // the walk: a small step per point toward a clamped wander, zero at the wall so the
          // trickle leaves the stain where the stain is
          h = SewerModel.mix(h ^ 0x68E31DA4);
          if (i > 0)
            wander += ((h % 1000) / 1000.0 - 0.5) * 2 * SewerStyle.STREAM_WALK;
          var amp = SewerStyle.STREAM_WANDER;
          if (wander > amp)
            wander = amp;
          if (wander < -amp)
            wander = -amp;
          var d = t * len;
          var x = sx + fx * d + lx * wander;
          var z = sz + fz * d + lz * wander;
          // a thread at the wall that opens to full width over the first quarter, with a
          // per-point jitter so the two edges are not parallel
          var hw = SewerStyle.STREAM_W / 2 * (0.35 + 0.65 * Math.min(1.0, t * 4)) *
            (1 + (((h >> 10) % 1000) / 1000.0 - 0.5) * 2 * SewerStyle.STREAM_JITTER);
          // off the walkway anywhere along the strip's edges = no trickle at all (the first point
          // sits ON the wall line, so it is tested a hair inside)
          var e = i == 0 ? 0.05 : 0.0;
          if (!onFloor(m, x + fx * e + lx * hw, z + fz * e + lz * hw) ||
              !onFloor(m, x + fx * e - lx * hw, z + fz * e - lz * hw))
            return null;
          // fade in over the first step out of the grime band, and out across the pool it runs into
          var a = Math.min(1.0, d / SewerStyle.STREAM_STEP);
          var tail = (len - d) / SewerStyle.STREAM_FADE;
          if (tail < a)
            a = tail;
          pts.push({
            x: x,
            z: z,
            hw: hw,
            a: a,
          });
        }
      return pts;
    }

// is a world point over a floor cell?
  static inline function onFloor(m:Sewer, x:Float, z:Float):Bool
    {
      var half = (CityConfig.GRID * CELL) / 2;
      return SewerModel.isFloor(m, Math.floor((x + half) / CELL), Math.floor((z + half) / CELL));
    }

// one trickle as a strip four vertices across — edge, inner, inner, edge, alpha 0/1/1/0 — so both
// edges are soft. u runs down the spine in world units over STREAM_TILE, v takes a band of the
// swatch exactly as wide as the strip at that same scale, so the texture is never stretched. the
// miter is SlimeTrail.rebuild's: the perpendicular of the averaged tangent at each point
  static function strip(s:Array<SewerStreamPoint>, pos:Array<Float>, uv:Array<Float>, col:Array<Float>, idx:Array<Int>):Void
    {
      var y = SewerStyle.STREAM_Y;
      var T = SewerStyle.STREAM_TILE;
      var base = Std.int(pos.length / 3);
      var u = 0.0;
      for (i in 0...s.length)
        {
          var p = s[i];
          var a = s[i > 0 ? i - 1 : i];
          var b = s[i < s.length - 1 ? i + 1 : i];
          var tx = b.x - a.x;
          var tz = b.z - a.z;
          var tl = Math.sqrt(tx * tx + tz * tz);
          // the perpendicular in XZ
          var px = -tz / tl;
          var pz = tx / tl;
          if (i > 0)
            u += Math.sqrt((p.x - s[i - 1].x) * (p.x - s[i - 1].x) + (p.z - s[i - 1].z) * (p.z - s[i - 1].z)) / T;
          for (k in 0...4)
            {
              var f = [-1.0, -SewerStyle.STREAM_CORE, SewerStyle.STREAM_CORE, 1.0][k];
              pos.push(p.x + px * p.hw * f);
              pos.push(y);
              pos.push(p.z + pz * p.hw * f);
              uv.push(u);
              uv.push(0.5 + p.hw * f / T);
              col.push(1.0);
              col.push(1.0);
              col.push(1.0);
              col.push(k == 0 || k == 3 ? 0.0 : p.a);
            }
          if (i == 0)
            continue;
          // three quads between this row of four and the last, wound so the normal comes out +Y
          var r0 = base + (i - 1) * 4;
          var r1 = base + i * 4;
          for (k in 0...3)
            {
              idx.push(r0 + k);
              idx.push(r0 + k + 1);
              idx.push(r1 + k);
              idx.push(r0 + k + 1);
              idx.push(r1 + k + 1);
              idx.push(r1 + k);
            }
        }
    }

// one pool at (cx,cz), shrunk until its rotated footprint lies on floor cells only; false (and no
// pool) if even POOL_MIN does not fit. the cell and the yaw come off the hash, the aspect off the
// atlas cell
  static function place(m:Sewer, pools:Array<SewerPool>, cx:Float, cz:Float, size:Float, hh:Int):Bool
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
              return true;
            }
          size *= 0.85;
        }
      return false;
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
