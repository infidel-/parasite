package render.sewer;

import three.Three;
import citygen.CityConfig;
import const.CultBaseConst;
import cult.base.CultBaseOrgan;
import game.Game;
import render.Textures;
import render.sewer.SewerModel.Sewer;
import render.world.ObjModels;
import render.world.PropGlow;
import render.world.PropShader.ShaderPatch;
import render.world.VisionMask;

// one vessel run between two organs
typedef CultEdge = {
  // the run starts inside this organ's footprint (the parent end)
  var a:CultBaseOrgan;
  // and ends inside this one's
  var b:CultBaseOrgan;
  // the smoothed path on the floor, world units
  var curve:CatmullRomCurve3;
  // its arc length
  var len:Float;
  // distance along the tree from the Cor at its start: the pulse phase
  var s0:Float;
  // hops from the Cor: the radius tapers with it
  var depth:Int;
  // the organ whose build grew it (its birth time drives the grow-in)
  var owner:Int;
}

// one decal quad of the PACK4 sheet
typedef CultQuad = {
  // 0 rim, 1 splotch A, 2 splotch B, 3 branch (rooted at its origin, growing along +x)
  var cell:Int;
  // world centre (the root, for a branch)
  var x:Float;
  var z:Float;
  // world size of the whole tile
  var size:Float;
  // turn about y
  var yaw:Float;
  // the fade-in: starts at `start` on PropGlow's clock and takes `dur`. left out at the call
  // sites and filled from the owner's birth by CultDetail.grown
  @:optional var start:Float;
  @:optional var dur:Float;
}

// the cult base taking over its habitat floor: a flesh rim under every organ, splotches around it,
// vein branches out of the rim and off the vessels, and a pulsing vessel tube from each organ to its
// parent (the Cor or the nearest organ built before it), plus one extra link to a close neighbour.
// docs/jobs/cult-detail/preview.src.html is the spec and the layout below is a line-for-line port of
// it, same rng and hashes, so one base draws the same picture in both.
// DERIVED, NEVER STORED: a function of each organ's (id, type, x, y) and the floor grid, seeded per
// organ id, so building organ k adds only k's detail and nothing already drawn moves.
// three merged meshes: +3 draw calls in a base habitat, nothing anywhere else
class CultDetail
{
  // the approved preview knobs
  static inline var SEED = 7;
  static inline var DENSITY = 2.5;
  static inline var RIM = 1.85;        // rim tile width in footprint widths
  static inline var THICK = 1.25;      // vessel radius scale
  static inline var GAP = 4.0;         // cells between two pulses running down a vessel
  static inline var SWELL = 0.04;      // radius bulge at a pulse peak
  static inline var GLOW = 0.2;        // brightening at a pulse peak, multiplied into the lit colour
  static inline var BUMP = 1.0;        // the sheet as its own bump map: the wet glints on the ridges
  static inline var GROW = 7.0;        // BASE_MS units a new organ's detail takes to grow in
  static inline var RADIAL = 10;       // vessel ring segments
  static inline var SKIN_LEN = 3.6;    // world length of one vessel-skin tile (its 8 ribs), round the ring too
  static inline var SPLOTCH_ALPHA = 0.6; // splotch opacity: at full they read clearer than the rims they sit under
  static inline var SPLOTCH = 4;       // CultQuad.cell of the first splotch: 4 + k is cell k of the 4x4 splotch sheet
  // the splotch cells in use: 13 is retired, too light against the floor
  static var SPLOTCH_CELLS = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15 ];
  static inline var TINT_RAMP = 40.0;  // BASE_MS units the habitat takes to turn cult-pink after its first organ (6 s)
  public static inline var TINT_NEVER = 1e9; // tintBorn with no base in the area: the grade never starts
  // the cult grade (see grade): rgb multiplier, normalised to keep luma in the shader; w its strength
  public static var tint = { value: new Vector4(1.0, 0.8, 0.92, 1.0) };
  // shadow lift toward the cult's deep magenta, under the same strength. added BEFORE the sRGB curve:
  // 0.02 lifted black to ~39/255, a magenta wash; 0.0025 is ~10
  public static var tintLift = { value: new Vector3(0.0025, 0.0, 0.0015) };
  // x: PropGlow-clock time the base began in this area (TINT_NEVER without one, reset per area build); y: ramp
  public static var tintBorn = { value: new Vector2(TINT_NEVER, TINT_RAMP) };
  static inline var BORN_OLD = -1e6;   // birth of everything already there at the area's first build
  static inline var COR_KEY = 'cult_cor_nefandum'; // the Cor's prop row key in render.world.ObjModels
  // the branch tile's thick root sits at (25, 235.5) of its 512 quarter: moved to the quad's origin
  static inline var ROOT_X = 0.5 - 25 / 512;
  static inline var ROOT_Z = 0.5 - 235.5 / 512;

  var scene:Scene;
  var game:Game;
  var model:Sewer;
  var decalMat:Dynamic;               // patched MeshStandardMaterial (the hook externs are untyped)
  var splotchMat:Dynamic;             // the same, over the splotch sheet: one program, its own map
  var tubeMat:Dynamic;
  var corPos = { value: new Vector3() }; // the Cor instance's translation: its beat phase hash
  var corSynced = false;              // corPos copied off the live Cor instance since the last rebuild
  var meshes:Array<Mesh> = [];
  var born:Map<Int, Float> = null;    // organ id -> birth on PropGlow's clock; null before the first build
  var owner:Map<Int, CultBaseOrgan>;  // floor cell -> the organ standing on it
  var organs:Array<CultBaseOrgan>;
  var cor:CultBaseOrgan;

  public function new(scene:Scene, game:Game, model:Sewer)
    {
      this.scene = scene;
      this.game = game;
      this.model = model;
      decalMat = decalMaterial('textures/cult/flesh-decals.png', 1.0);
      splotchMat = decalMaterial('textures/cult/flesh-splotches.png', SPLOTCH_ALPHA);
      var skin = Textures.loadTexture('textures/cult/vessel-skin.png', 'wall');
      tubeMat = VisionMask.patch(vessel(new MeshStandardMaterial({
        map: skin,
        bumpMap: skin,
        bumpScale: BUMP,
        roughness: 0.4,
        metalness: 0.0,
      }), corPos));
    }

// a floor decal material over one sheet at an opacity: the sheet is its own bump map for the wet glints
  static function decalMaterial(path:String, opacity:Float):Dynamic
    {
      var tex = Textures.loadTexture(path, 'wall');
      return VisionMask.patch(decal(new MeshStandardMaterial({
        map: tex,
        bumpMap: tex,
        bumpScale: BUMP,
        roughness: 0.35,
        metalness: 0.0,
        transparent: true,
        opacity: opacity,
        depthWrite: false,
        side: THREE.FrontSide,
        polygonOffset: true,
        polygonOffsetFactor: -2,
        polygonOffsetUnits: -2,
      })));
    }

// the habitat's cult grade, patched into the composer's OutputPass after its tone map: no pass of
// its own, a few ALU per pixel, and strength 0 wherever tintBorn is TINT_NEVER (every other area)
  public static function grade(out:OutputPass):Void
    {
      out.uniforms.cultTime = PropGlow.uTime;
      out.uniforms.cultTint = tint;
      out.uniforms.cultLift = tintLift;
      out.uniforms.cultBorn = tintBorn;
      var fs = StringTools.replace(out.material.fragmentShader, 'uniform sampler2D tDiffuse;',
        'uniform sampler2D tDiffuse;\n' +
        'uniform float cultTime;\n' +
        'uniform vec4 cultTint;\n' +
        'uniform vec3 cultLift;\n' +
        'uniform vec2 cultBorn;');
      out.material.fragmentShader = StringTools.replace(fs, '// color space',
        'float cultK = cultTint.w * clamp( ( cultTime - cultBorn.x ) / cultBorn.y, 0.0, 1.0 );\n' +
        'vec3 cultW = vec3( 0.2126, 0.7152, 0.0722 );\n' +
        'vec3 cultC = gl_FragColor.rgb * cultTint.rgb / dot( cultTint.rgb, cultW ) +\n' +
        '  cultLift * ( 1.0 - dot( gl_FragColor.rgb, cultW ) );\n' +
        'gl_FragColor.rgb = mix( gl_FragColor.rgb, cultC, cultK );\n' +
        '// color space');
    }

// compile both programs in a warm scene: one quad and one short vessel through the same materials,
// patched in the same order as a real build, so entering a base habitat compiles nothing
  public static function warm(scene:Scene):Void
    {
      var d = new CultDetail(scene, null, null);
      d.born = [ 0 => 0.0 ];
      d.organs = [];
      var curve = new CatmullRomCurve3([ new Vector3(0, 0, 0), new Vector3(4, 0, 0) ], false, 'centripetal', 0.5);
      d.emit([
        {
          cell: 0,
          x: 0.0,
          z: 0.0,
          size: 1.0,
          yaw: 0.0,
          start: 0.0,
          dur: 1.0,
        },
        {
          cell: SPLOTCH,
          x: 0.0,
          z: 0.0,
          size: 1.0,
          yaw: 0.0,
          start: 0.0,
          dur: 1.0,
        }
      ], [
        {
          a: null,
          b: null,
          curve: curve,
          len: curve.getLength(),
          s0: 0.0,
          depth: 0,
          owner: 0,
        }
      ]);
    }

// drop the old meshes and draw the base's detail again. called on area build and on every
// refreshObjects. ponytail: a 2x2 organ refreshes once per footprint cell, so this runs 4 times for
// one build; births are keyed by id, so all 4 draw the same thing. batch it if it ever shows in a profile
  public function rebuild():Void
    {
      for (m in meshes)
        {
          scene.remove(m);
          m.geometry.dispose();
        }
      meshes = [];
      var base = (game.cults.length > 0 ? game.cults[0].base : null);
      if (base == null ||
          base.areaID != game.area.id)
        {
          tintBorn.value.x = TINT_NEVER;
          return;
        }
      cor = base.getHeart();
      organs = base.organs.copy();
      organs.sort(function(p, q) return p.id - q.id);
      // births: whatever stood here at the first build is old, an id seen later grows in from now
      var now = PropGlow.uTime.value;
      var first = (born == null);
      if (first)
        born = new Map();
      for (o in organs)
        if (!born.exists(o.id))
          born.set(o.id, first ? BORN_OLD : now);
      // the grade starts with the first organ: at once for a base already standing, ramped for a new one
      tintBorn.value.x = TINT_NEVER;
      for (o in organs)
        tintBorn.value.x = Math.min(tintBorn.value.x, born.get(o.id));
      owner = new Map();
      for (o in organs)
        for (c in cells(o))
          owner.set(c.r * model.w + c.c, o);
      corSynced = false;
      var edges = topology();
      var splotches:Array<CultQuad> = [];
      var rims:Array<CultQuad> = [];
      var branches:Array<CultQuad> = [];
      // branches off the vessels
      for (e in edges)
        {
          var r = gen.Rng.mulberry32(hash([ SEED, e.a.id, e.b.id, 23 ]));
          var r0 = radius(e);
          var n = Math.round(e.len / (1.5 * CityConfig.CELL) * DENSITY);
          var p = new Vector3();
          var tg = new Vector3();
          for (i in 0...n)
            {
              var t = 0.12 + r() * 0.76;
              e.curve.getPointAt(t, p);
              e.curve.getTangentAt(t, tg);
              var side = (r() < 0.5 ? -1 : 1);
              var ang = Math.atan2(tg.z, tg.x) + side * (0.7 + r() * 0.75);
              var dx = Math.cos(ang);
              var dz = Math.sin(ang);
              if (!floorAt(cellX(p.x), cellZ(p.z)))
                continue;
              branches.push(grown(e.owner, false, {
                cell: 3,
                x: p.x + dx * r0 * 0.6,
                z: p.z + dz * r0 * 0.6,
                size: (0.9 + r() * 0.9) * CityConfig.CELL,
                yaw: Math.atan2(-dz, dx),
              }));
            }
        }
      // per organ: its rim, splotches round it, branches out of the rim
      for (o in order())
        {
          var r = gen.Rng.mulberry32(hash([ SEED, o.id, 5 ]));
          var info = CultBaseConst.info(o.type);
          var oc = centreC(o);
          var or = centreR(o);
          var big = Math.max(info.w, info.h);
          var rim = big * CityConfig.CELL * RIM;
          var wo = CityConfig.cellToWorld(oc, or);
          rims.push(grown(o.id, true, {
            cell: 0,
            x: wo.x,
            z: wo.z,
            size: rim,
            yaw: r() * Math.PI * 2,
          }));
          var count = Math.round((info.w * info.h > 1 ? 3 : 1.5) * DENSITY + r() * 0.8);
          var i = 0;
          var tries = 0;
          while (i < count &&
              tries < 40)
            {
              tries++;
              var size = (0.7 + r() * 0.8) * CityConfig.CELL;
              var ang = r() * Math.PI * 2;
              var dist = big * 0.6 + r() * 2.4;
              var fc = oc + Math.cos(ang) * dist;
              var fr = or + Math.sin(ang) * dist;
              if (!discOnFloor(fc, fr, size / CityConfig.CELL * 0.4))
                continue;
              var ws = CityConfig.cellToWorld(fc, fr);
              // the quad's whole circumradius, not the disc: the splotch art reaches into the corners
              if (onGrate(ws.x, ws.z, size * 0.71))
                continue;
              // the field order is the roll order: the tile pick, then the turn
              splotches.push(grown(o.id, false, {
                cell: SPLOTCH + SPLOTCH_CELLS[Std.int(r() * SPLOTCH_CELLS.length)],
                x: ws.x,
                z: ws.z,
                size: size,
                yaw: r() * Math.PI * 2,
              }));
              i++;
            }
          var nb = Math.round(2 * DENSITY);
          for (k in 0...nb)
            {
              var ang = r() * Math.PI * 2;
              var dx = Math.cos(ang);
              var dz = Math.sin(ang);
              var start = rim * 0.3 / CityConfig.CELL;
              var fc = oc + dx * start;
              var fr = or + dz * start;
              if (!floorAt(fc, fr))
                continue;
              var wb = CityConfig.cellToWorld(fc, fr);
              branches.push(grown(o.id, false, {
                cell: 3,
                x: wb.x,
                z: wb.z,
                size: (1.0 + r() * 0.8) * CityConfig.CELL,
                yaw: Math.atan2(-dz, dx),
              }));
            }
        }
      // drawn in the preview's layer order: splotches, then rims over them, then the branches on top
      emit(splotches.concat(rims).concat(branches), edges);
    }

// copy the Cor instance's translation into the vessels' phase hash, the first frame its batch is
// there. PropGlow hashes the beat phase off instanceMatrix[3], which carries the glb's recentring
// (measured -160.0048 / -159.9958 against a cell maths -160 / -160) and only exists once the glb has
// loaded; the hash is fract(sin(.) * 43758), so anything but the same float32s is a different phase
  public function syncCor(props:Array<render.world.ObjModels.PropBatch>):Void
    {
      if (corSynced ||
          cor == null)
        return;
      for (b in props)
        if (b.model.keys.indexOf(COR_KEY) >= 0 &&
            b.solid.mesh != null)
          {
            var a = b.solid.mesh.instanceMatrix.array;
            corPos.value.set(a[12], a[13], a[14]);
            corSynced = true;
          }
    }

// stamp a quad's grow-in off its owner's birth: the rim fades over the whole grow, the rest come in
// once the vessel has started (the preview's max(0, 1.6 f - 0.6))
  function grown(ownerID:Int, isRim:Bool, q:CultQuad):CultQuad
    {
      var b = born.get(ownerID);
      q.start = (isRim ? b : b + 0.375 * GROW);
      q.dur = (isRim ? GROW : 0.625 * GROW);
      return q;
    }

// build the three merged meshes: the splotches, the rims and branches, the vessels. the two decal
// meshes tie on renderOrder and on z (both sit at the origin), so three falls back to construction
// order: the splotch mesh is made first and draws under the rims, as the preview layers them
  function emit(quads:Array<CultQuad>, edges:Array<CultEdge>):Void
    {
      decals([ for (q in quads) if (q.cell >= SPLOTCH) q ], splotchMat);
      decals([ for (q in quads) if (q.cell < SPLOTCH) q ], decalMat);
      if (edges.length > 0)
        {
          var pos:Array<Float> = [];
          var nor:Array<Float> = [];
          var uv:Array<Float> = [];
          var tb:Array<Float> = [];
          var idx:Array<Int> = [];
          for (e in edges)
            tube(e, pos, nor, uv, tb, idx);
          var g = new BufferGeometry();
          g.setAttribute('position', new Float32BufferAttribute(pos, 3));
          g.setAttribute('normal', new Float32BufferAttribute(nor, 3));
          g.setAttribute('uv', new Float32BufferAttribute(uv, 2));
          g.setAttribute('cultTube', new Float32BufferAttribute(tb, 4));
          g.setIndex(idx);
          add(new Mesh(g, tubeMat));
        }
    }

// one merged quad mesh: rim and branch tiles are quarters of the decal sheet, a splotch is a
// cell of the 4x4 splotch sheet
  function decals(quads:Array<CultQuad>, mat:Dynamic):Void
    {
      if (quads.length > 0)
        {
          var pos:Array<Float> = [];
          var nor:Array<Float> = [];
          var uv:Array<Float> = [];
          var fd:Array<Float> = [];
          var idx:Array<Int> = [];
          for (q in quads)
            {
              var ca = Math.cos(q.yaw);
              var sa = Math.sin(q.yaw);
              var k = q.cell - SPLOTCH;
              var tw = (k >= 0 ? 0.25 : 0.5);
              var u0 = (k >= 0 ? (k % 4) * 0.25 : (q.cell % 2) * 0.5);
              var v0 = (k >= 0 ? 0.75 - Std.int(k / 4) * 0.25 : (q.cell < 2 ? 0.5 : 0.0));
              var ox = (q.cell == 3 ? ROOT_X : 0.0);
              var oz = (q.cell == 3 ? ROOT_Z : 0.0);
              var base = Std.int(pos.length / 3);
              // PlaneGeometry(1, 1).rotateX(-PI / 2)'s corner order, so v = 1 is the tile's top edge (-z)
              for (k in 0...4)
                {
                  var lx = (k % 2 == 0 ? -0.5 : 0.5);
                  var lz = (k < 2 ? -0.5 : 0.5);
                  var px = (lx + ox) * q.size;
                  var pz = (lz + oz) * q.size;
                  pos.push(q.x + px * ca + pz * sa);
                  pos.push(SewerStyle.FLOOR_DECAL_Y);
                  pos.push(q.z - px * sa + pz * ca);
                  nor.push(0);
                  nor.push(1);
                  nor.push(0);
                  uv.push(u0 + (lx + 0.5) * tw);
                  uv.push(v0 + (0.5 - lz) * tw);
                  fd.push(q.start);
                  fd.push(q.dur);
                }
              for (k in [ 0, 2, 1, 2, 3, 1 ])
                idx.push(base + k);
            }
          var g = new BufferGeometry();
          g.setAttribute('position', new Float32BufferAttribute(pos, 3));
          g.setAttribute('normal', new Float32BufferAttribute(nor, 3));
          g.setAttribute('uv', new Float32BufferAttribute(uv, 2));
          g.setAttribute('cultFade', new Float32BufferAttribute(fd, 2));
          g.setIndex(idx);
          add(new Mesh(g, mat));
        }
    }

  function add(m:Mesh):Void
    {
      m.receiveShadow = true;
      scene.add(m);
      meshes.push(m);
    }

// one vessel's rings, TubeGeometry's layout and winding: radius tapered by depth and wobbled along s,
// half sunk into the floor. the ring's side axis lies on the floor, so (side, up) is TubeGeometry's
// (N, B) for a level path. per vertex: s along the tree, radius, 0..1 along this run, birth. the skin
// runs along s and round the ring by arc length, both over SKIN_LEN, so its texels stay square; the
// ring's v jump sits on the face past 3/4 of the ring, the sunk underside
  function tube(e:CultEdge, pos:Array<Float>, nor:Array<Float>, uv:Array<Float>, tb:Array<Float>,
      idx:Array<Int>):Void
    {
      var segs = Std.int(Math.max(24, Math.round(e.len * 5)));
      var r0 = radius(e);
      var b = born.get(e.owner);
      var base = Std.int(pos.length / 3);
      var p = new Vector3();
      var t = new Vector3();
      for (i in 0...segs + 1)
        {
          var u = i / segs;
          e.curve.getPointAt(u, p);
          e.curve.getTangentAt(u, t);
          var s = e.s0 + u * e.len;
          var r = (r0 + (r0 * 0.72 - r0) * u) * (1 + 0.13 * Math.sin(s * 1.7) + 0.08 * Math.sin(s * 4.3 + 1));
          var sl = Math.sqrt(t.x * t.x + t.z * t.z);
          var sx = t.z / sl;
          var sz = -t.x / sl;
          var dive = nestDive(p.x, p.z);
          for (j in 0...RADIAL + 1)
            {
              var v = j / RADIAL * Math.PI * 2;
              var nc = -Math.cos(v);
              var ns = Math.sin(v);
              var nx = nc * sx;
              var ny = ns;
              var nz = nc * sz;
              pos.push(p.x + nx * r);
              pos.push(p.y + r * (0.55 - 1.6 * dive) + ny * r);
              pos.push(p.z + nz * r);
              nor.push(nx);
              nor.push(ny);
              nor.push(nz);
              uv.push(s / SKIN_LEN);
              uv.push((j <= Std.int(RADIAL * 0.75) ? j : j - RADIAL) / RADIAL * Math.PI * 2 * r / SKIN_LEN);
              tb.push(s);
              tb.push(r);
              tb.push(u);
              tb.push(b);
            }
        }
      for (j in 1...segs + 1)
        for (i in 1...RADIAL + 1)
          {
            var a = base + (RADIAL + 1) * (j - 1) + (i - 1);
            var bb = base + (RADIAL + 1) * j + (i - 1);
            var c = base + (RADIAL + 1) * j + i;
            var d = base + (RADIAL + 1) * (j - 1) + i;
            idx.push(a);
            idx.push(bb);
            idx.push(d);
            idx.push(bb);
            idx.push(c);
            idx.push(d);
          }
    }

  static inline function radius(e:CultEdge):Float
    return Math.max(0.15, 0.285 - e.depth * 0.035) * THICK;

// 0..1, how far a vessel point has dived under the floor near a rat nest: the nest's hole shows the
// floor through it, so a run dives from half a cell outside the footprint and is gone 0.3 inside it
  function nestDive(x:Float, z:Float):Float
    {
      var fc = cellX(x);
      var fr = cellZ(z);
      var dive = 0.0;
      for (o in organs)
        if (o.type == _CultBaseOrganType.RAT_NEST)
          {
            var info = CultBaseConst.info(o.type);
            var dx = Math.max(o.x - 0.5 - fc, fc - (o.x + info.w - 0.5));
            var dz = Math.max(o.y - 0.5 - fr, fr - (o.y + info.h - 0.5));
            var t = Math.min(Math.max((0.5 - Math.max(dx, dz)) / 0.8, 0), 1);
            dive = Math.max(dive, t * t * (3 - 2 * t));
          }
      return dive;
    }

// the Cor first, then the rest in build (id) order
  function order():Array<CultBaseOrgan>
    {
      return [ cor ].concat([ for (o in organs) if (o != cor) o ]);
    }

// each organ joins the nearest node already connected, so the tree only ever grows; an organ close
// to an earlier one that is not its parent gets one extra link to it
  function topology():Array<CultEdge>
    {
      var edges:Array<CultEdge> = [];
      var s0 = new Map<Int, Float>();
      var depth = new Map<Int, Int>();
      s0.set(cor.id, 0.0);
      depth.set(cor.id, 0);
      var done = [ cor ];
      for (o in order().slice(1))
        {
          var oc = centreC(o);
          var or = centreR(o);
          var best:CultBaseOrgan = null;
          var bd = Math.POSITIVE_INFINITY;
          for (n in done)
            {
              var d = js.lib.Math.hypot(centreC(n) - oc, centreR(n) - or);
              if (d < bd)
                {
                  bd = d;
                  best = n;
                }
            }
          var e = makeEdge(best, o, s0.get(best.id), depth.get(best.id) + 1, o.id);
          if (e != null)
            {
              edges.push(e);
              s0.set(o.id, e.s0 + e.len);
              depth.set(o.id, e.depth);
            }
          else
            {
              s0.set(o.id, s0.get(best.id));
              depth.set(o.id, depth.get(best.id) + 1);
            }
          // the first of the closest (the preview's stable sort, then [0])
          var near:CultBaseOrgan = null;
          for (n in done)
            if (n != best &&
                n != cor &&
                gap(n, o) <= 3 &&
                (near == null || gap(n, o) < gap(near, o)))
              near = n;
          if (near != null)
            {
              var lo = (s0.get(near.id) <= s0.get(o.id) ? near : o);
              var e2 = makeEdge(lo, lo == near ? o : near, s0.get(lo.id),
                Std.int(Math.max(depth.get(near.id), depth.get(o.id))) + 1, o.id);
              if (e2 != null)
                edges.push(e2);
            }
          done.push(o);
        }
      return edges;
    }

// a run from a to b: the A* cells, collinear ones thinned, the rest jittered so it reads grown and
// not routed, through a centripetal Catmull-Rom
  function makeEdge(a:CultBaseOrgan, b:CultBaseOrgan, s0:Float, depth:Int, ownerID:Int):CultEdge
    {
      var path = astar(a, b, ownerID);
      if (path == null)
        return null;
      var r = gen.Rng.mulberry32(hash([ SEED, a.id, b.id, 11 ]));
      var pts = [ CityConfig.cellToWorld(centreC(a), centreR(a)) ];
      for (i in 1...path.length - 1)
        {
          var p = path[i - 1];
          var c = path[i];
          var n = path[i + 1];
          if (c.c - p.c == n.c - c.c &&
              c.r - p.r == n.r - c.r &&
              i % 2 == 1)
            continue;
          var jc = c.c + (r() - 0.5) * 0.45;
          var jr = c.r + (r() - 0.5) * 0.45;
          pts.push(CityConfig.cellToWorld(jc, jr));
        }
      pts.push(CityConfig.cellToWorld(centreC(b), centreR(b)));
      var curve = new CatmullRomCurve3([ for (p in pts) new Vector3(p.x, 0, p.z) ], false, 'centripetal', 0.5);
      return {
        a: a,
        b: b,
        curve: curve,
        len: curve.getLength(),
        s0: s0,
        depth: depth,
        owner: ownerID,
      };
    }

// A* over floor cells, 8 directions, a step next to masonry costs 0.6 more; other organs block, the
// two end footprints are passable. the open list pops the FIRST lowest f, which is what the preview's
// stable sort + shift picks, so ties break the same way.
// only organs built BEFORE the run's owner block it: one built later on top of an old vessel leaves
// the vessel where it was, running under the new body, or every build could reroute the base
  function astar(a:CultBaseOrgan, b:CultBaseOrgan, ownerID:Int):Array<{ c:Int, r:Int }>
    {
      var bc = centreC(b);
      var br = centreR(b);
      var g = new Map<Int, Float>();
      var prev = new Map<Int, Int>();
      var open:Array<{ f:Float, c:Int, r:Int }> = [];
      for (s in cells(a))
        {
          g.set(s.r * model.w + s.c, 0.0);
          open.push({
            f: js.lib.Math.hypot(s.c - bc, s.r - br),
            c: s.c,
            r: s.r,
          });
        }
      while (open.length > 0)
        {
          var bi = 0;
          for (i in 1...open.length)
            if (open[i].f < open[bi].f)
              bi = i;
          var cur = open.splice(bi, 1)[0];
          var ck = cur.r * model.w + cur.c;
          if (owner.get(ck) == b)
            {
              var path = [ { c: cur.c, r: cur.r } ];
              var k = ck;
              while (prev.exists(k))
                {
                  k = prev.get(k);
                  path.unshift({ c: k % model.w, r: Std.int(k / model.w) });
                }
              return path;
            }
          for (dy in -1...2)
            for (dx in -1...2)
              {
                if (dx == 0 &&
                    dy == 0)
                  continue;
                var nc = cur.c + dx;
                var nr = cur.r + dy;
                if (!pass(nc, nr, a, b, ownerID) ||
                    (dx != 0 &&
                     dy != 0 &&
                     (!pass(cur.c + dx, cur.r, a, b, ownerID) || !pass(cur.c, cur.r + dy, a, b, ownerID))))
                  continue;
                var cost = g.get(ck) + (dx != 0 && dy != 0 ? 1.414 : 1.0) + (nearWall(nc, nr) ? 0.6 : 0.0);
                var nk = nr * model.w + nc;
                if (!g.exists(nk) ||
                    cost < g.get(nk))
                  {
                    g.set(nk, cost);
                    prev.set(nk, ck);
                    open.push({
                      f: cost + js.lib.Math.hypot(nc - bc, nr - br),
                      c: nc,
                      r: nr,
                    });
                  }
              }
        }
      return null;
    }

// a cell a run may cross: floor nobody stands on, either end organ's own footprint, or an organ
// built after the run's owner
  function pass(c:Int, r:Int, a:CultBaseOrgan, b:CultBaseOrgan, ownerID:Int):Bool
    {
      if (!SewerModel.isFloor(model, c, r))
        return false;
      var o = owner.get(r * model.w + c);
      return (o == null ||
        o == a ||
        o == b ||
        o.id > ownerID);
    }

  inline function nearWall(c:Int, r:Int):Bool
    {
      return !SewerModel.isFloor(model, c - 1, r) ||
        !SewerModel.isFloor(model, c + 1, r) ||
        !SewerModel.isFloor(model, c, r - 1) ||
        !SewerModel.isFloor(model, c, r + 1);
    }

  inline function floorAt(fc:Float, fr:Float):Bool
    return SewerModel.isFloor(model, Math.round(fc), Math.round(fr));

// does a world disc touch one of the tunnel's drains? (none in a cave: its floor scatter lays none)
  function onGrate(x:Float, z:Float, rad:Float):Bool
    {
      if (model.drains == null)
        return false;
      for (g in model.drains)
        if ((g.x - x) * (g.x - x) + (g.z - z) * (g.z - z) < (g.r + rad) * (g.r + rad))
          return true;
      return false;
    }

// a decal of radius rad (cells) at (fc, fr) only where its whole disc stays on floor
  function discOnFloor(fc:Float, fr:Float, rad:Float):Bool
    {
      if (!floorAt(fc, fr))
        return false;
      for (i in 0...8)
        {
          var a = i / 8 * Math.PI * 2;
          if (!floorAt(fc + Math.cos(a) * rad, fr + Math.sin(a) * rad))
            return false;
        }
      return true;
    }

// fractional cell of a world coordinate (cell centres at integers), the inverse of cellToWorld
  static inline function cellX(x:Float):Float
    return x / CityConfig.CELL + CityConfig.GRID / 2 - 0.5;

  static inline function cellZ(z:Float):Float
    return z / CityConfig.CELL + CityConfig.GRID / 2 - 0.5;

// an organ's footprint centre in fractional cells
  static function centreC(o:CultBaseOrgan):Float
    return o.x + (CultBaseConst.info(o.type).w - 1) / 2;

  static function centreR(o:CultBaseOrgan):Float
    return o.y + (CultBaseConst.info(o.type).h - 1) / 2;

// the empty cells between two footprints along the worse axis (0 when they touch)
  static function gap(a:CultBaseOrgan, b:CultBaseOrgan):Int
    {
      var ia = CultBaseConst.info(a.type);
      var ib = CultBaseConst.info(b.type);
      var gx = Std.int(Math.max(Math.max(a.x - (b.x + ib.w - 1), b.x - (a.x + ia.w - 1)), 0));
      var gy = Std.int(Math.max(Math.max(a.y - (b.y + ib.h - 1), b.y - (a.y + ia.h - 1)), 0));
      return Std.int(Math.max(gx, gy));
    }

  static function cells(o:CultBaseOrgan):Array<{ c:Int, r:Int }>
    {
      var info = CultBaseConst.info(o.type);
      return [ for (dy in 0...info.h) for (dx in 0...info.w) { c: o.x + dx, r: o.y + dy } ];
    }

// the preview's FNV-style mix of a few ints. v * 2654435761 is a double product there, exact below
// 2^53 and cut to 32 bits by >>> 0, which is what Std.int's | 0 does here; the rest is bit-identical
  static function hash(n:Array<Int>):Int
    {
      var h = 0x811C9DC5;
      for (v in n)
        {
          h ^= Std.int(v * 2654435761.0);
          h = js.lib.Math.imul(h ^ (h >>> 15), 0x85EBCA77);
        }
      return h;
    }

// the decal material: the sheet as its own bump map for the wet glints, and a per-vertex fade for the
// grow-in. `mat` is Dynamic for the reason render.world.PropShader.patch gives: the material externs
// declare no onBeforeCompile / customProgramCacheKey
  static function decal(mat:Dynamic):Dynamic
    {
      mat.onBeforeCompile = function(shader:ShaderPatch, renderer:Dynamic)
        {
          shader.uniforms.cultTime = PropGlow.uTime;
          shader.vertexShader = 'attribute vec2 cultFade;\n' +
            'uniform float cultTime;\n' +
            'varying float vCultFade;\n' +
            StringTools.replace(shader.vertexShader, '#include <begin_vertex>',
              '#include <begin_vertex>\n' +
              '  vCultFade = clamp( ( cultTime - cultFade.x ) / cultFade.y, 0.0, 1.0 );');
          shader.fragmentShader = 'varying float vCultFade;\n' +
            StringTools.replace(shader.fragmentShader, '#include <alphatest_fragment>',
              '  diffuseColor.a *= vCultFade;\n' +
              '#include <alphatest_fragment>');
        };
      // a key of its own, or three could hand this program to a plain Standard material
      mat.customProgramCacheKey = function()
        return 'cultDecal';
      return mat;
    }

// the vessel material: the vessel-skin tile, the Cor's lub-dub running out along s
// (a small swell and a brightening multiplied into the lit colour), and the grow-in clipped along
// the run. the phase is PropGlow's flesh phase at the Cor's core, the same hash on the same
// instance translation, so a pulse leaves the Cor on its own kick
  static function vessel(mat:Dynamic, cor:Dynamic):Dynamic
    {
      var beat = { value: new Vector4(ObjModels.FLESH_RATE, GAP * CityConfig.CELL, SWELL, GLOW) };
      var grow = { value: GROW };
      mat.onBeforeCompile = function(shader:ShaderPatch, renderer:Dynamic)
        {
          shader.uniforms.cultTime = PropGlow.uTime;
          shader.uniforms.cultBeat = beat;
          shader.uniforms.cultCor = cor;
          shader.uniforms.cultGrow = grow;
          shader.vertexShader = 'attribute vec4 cultTube;\n' +
            'uniform float cultTime;\n' +
            'uniform vec4 cultBeat;\n' +
            'uniform vec3 cultCor;\n' +
            'uniform float cultGrow;\n' +
            'varying float vCultT;\n' +
            'varying float vCultGrow;\n' +
            'varying float vCultBeat;\n' +
            PropGlow.BEAT_GLSL +
            StringTools.replace(shader.vertexShader, '#include <begin_vertex>',
              '#include <begin_vertex>\n' +
              '  {\n' +
              '  float cph = fract( sin( cultCor.x * 12.9898 + cultCor.z * 78.233 ) * 43758.5453 );\n' +
              '  vCultBeat = propFleshBeatAt( cultTime * cultBeat.x + cph * 6.2832 -\n' +
              '    cultTube.x / cultBeat.y * 6.2832 );\n' +
              '  transformed += objectNormal * cultTube.y * cultBeat.z * vCultBeat;\n' +
              '  vCultT = cultTube.z;\n' +
              '  vCultGrow = clamp( ( cultTime - cultTube.w ) / cultGrow, 0.0, 1.0 );\n' +
              '  }');
          var f = shader.fragmentShader;
          f = StringTools.replace(f, '#include <clipping_planes_fragment>',
            '#include <clipping_planes_fragment>\n' +
            '  if ( vCultT > vCultGrow ) discard;');
          f = StringTools.replace(f, '#include <opaque_fragment>',
            '  outgoingLight *= 1.0 + vec3( 1.0, 0.3, 0.3 ) * vCultBeat * vCultBeat * cultBeat.w;\n' +
            '#include <opaque_fragment>');
          shader.fragmentShader = 'uniform vec4 cultBeat;\n' +
            'varying float vCultT;\n' +
            'varying float vCultGrow;\n' +
            'varying float vCultBeat;\n' +
            f;
        };
      mat.customProgramCacheKey = function()
        return 'cultVessel';
      return mat;
    }
}
