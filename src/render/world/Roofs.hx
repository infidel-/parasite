package render.world;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import citygen.CityModel.Building;
import render.RenderConfig;
import render.RenderConfig.TEXTURES;
import render.RenderConfig.DETAIL_TYPES;
import render.Textures;
import render.Poly.tag;

typedef Role = { post:Bool, outDir:Int, cx:Float, cz:Float };

// roof furniture: parapet rings + coping caps (flat-roof buildings), gable roofs
// (metal warehouses), fake contact shadows under the parapet, and instanced rooftop
// detail decals. Edge coverage / worn-face classification comes from Geom.
class Roofs {
  static inline var CELL = CityConfig.CELL;

  static inline function imax(a:Float, b:Float):Float return a > b ? a : b;

  // parapet ring: 4 corner posts + 4 inset rim segments (clean butt joints).
  // `covered` (per dir 0..3) lists world-axis intervals along each edge that are
  // shared with a same-height neighbour — those parts of the rim are dropped so
  // two attached buildings butt instead of overlapping (T/L junctions). A fully
  // covered edge yields no rim; a partially covered edge is split into the
  // exposed sub-spans, each adjusted at its junction end by `extend`: the brick
  // rim grows +T to fill the concave-corner square (overlap hidden under the cap),
  // while the cap retracts -E to butt against the perpendicular cap's outer edge
  // instead of overrunning the neighbour wall and z-fighting that cap's overhang
  public static function parapetRing(scene:Scene, b:Building, cx:Float, cz:Float, halfX:Float, halfZ:Float, yMid:Float, rimH:Float,
      matsFor:(Float, Float, Float, Role) -> Array<MeshStandardMaterial>, ?T:Float, ?covered:Array<Array<{a:Float, b:Float}>>, ?extend:Float):Void {
    if (T == null) T = RenderConfig.PARAPET_T;
    var EX = extend == null ? RenderConfig.PARAPET_T : extend;
    var ix = halfX - T / 2, iz = halfZ - T / 2;
    // a single-tex segment collapses to a baked-UV material with an identity map, so segments sharing a
    // texture differ only by placement: bake that into the verts and merge them into ONE mesh. bucket by
    // texture SOURCE, not just "collapsed or not" — a brick ring mixes clean and worn faces (isWornFace)
    // and an all-clean and an all-worn segment BOTH collapse, to different textures; merging those
    // together would repaint the worn ones clean. a ring is one building's, so the merge stays inside
    // the fade granularity Occlusion needs
    var mergeSrcs:Array<Dynamic> = [];
    var mergeMats:Array<Dynamic> = [];
    var mergeGeos:Array<Array<Dynamic>> = [];
    inline function add(w:Float, d:Float, x:Float, z:Float, post:Bool, outDir:Int) {
      var role:Role = { post: post, outDir: outDir, cx: x, cz: z };
      var geo = new BoxGeometry(w, rimH, d);
      var mats:Array<Dynamic> = cast matsFor(w, rimH, d, role);
      // single-tex coping collapses to one draw call (baked UVs); mixed-tex brick keeps its array
      var single = render.Poly.flattenBox(geo, mats, 'parapet-coping', 'parapet coping', 'textures/coping.png');
      if (!Std.isOfType(single, Array))
        {
          geo.translate(x, yMid, z);
          var src:Dynamic = untyped single.map.source; // clones share their source, so this groups by image
          var bi = mergeSrcs.indexOf(src);
          if (bi < 0)
            {
              bi = mergeSrcs.length;
              mergeSrcs.push(src);
              mergeMats.push(single);
              mergeGeos.push([]);
            }
          mergeGeos[bi].push(geo);
          return;
        }
      var m = new Mesh(geo, single);
      m.userData.b = b;
      m.position.set(x, yMid, z);
      scene.add(m);
    }
    // corner posts: always emitted with a cap. butting buildings only share edge
    // lines (never overlap area), so adjacent corner caps never z-fight
    for (sx in [-1, 1]) for (sz in [-1, 1]) add(T, T, cx + sx * ix, cz + sz * iz, true, -1);
    // rim segments along x (dir 0 +z / dir 1 -z), split around covered intervals
    var spanXLo = cx - (halfX - T), spanXHi = cx + (halfX - T);
    for (sz in [-1, 1]) {
      var dir = sz > 0 ? 0 : 1;
      var z = cz + sz * iz;
      for (seg in Geom.exposedSpans(covered, dir, spanXLo, spanXHi, EX)) {
        var w = seg.b - seg.a;
        if (w > 1e-6) add(w, T, (seg.a + seg.b) / 2, z, false, dir);
      }
    }
    // rim segments along z (dir 2 +x / dir 3 -x)
    var spanZLo = cz - (halfZ - T), spanZHi = cz + (halfZ - T);
    for (sx in [-1, 1]) {
      var dir = sx > 0 ? 2 : 3;
      var x = cx + sx * ix;
      for (seg in Geom.exposedSpans(covered, dir, spanZLo, spanZHi, EX)) {
        var d = seg.b - seg.a;
        if (d > 1e-6) add(T, d, x, (seg.a + seg.b) / 2, false, dir);
      }
    }
    // one merged mesh per texture. their verts are world-baked, so each sits at the origin and pick()'s
    // position fallback would bucket it into whatever building covers the city centre — the userData
    // tag is what keeps Occlusion fading it with its own building
    for (i in 0...mergeGeos.length)
      {
        var m = new Mesh(THREE.mergeGeometries(mergeGeos[i], false), mergeMats[i]);
        m.userData.b = b;
        scene.add(m);
      }
  }

  // coping face materials: world-tiled side lips (joints on a global grid) + a
  // matching world-tiled flat cap, so joints line up corner↔corner and top↔side
  static function copingMats(tex:Texture, tileW:Float, vOffset:Float = 0, prefix:String = 'coping', label:String = 'parapet coping')
      :(Float, Float, Float, Role) -> Array<MeshStandardMaterial> {
    return function(w:Float, rimH:Float, d:Float, role:Role):Array<MeshStandardMaterial> {
      var slice = (w < d ? w : d) / tileW;
      var VTILE = 1.5;
      inline function mat(ru:Float, rv:Float, rot:Float = 0, offX:Float = 0, offY:Float = 0, cy:Float = 0.5):MeshStandardMaterial {
        var t = tex.clone();
        t.needsUpdate = true;
        t.center.set(0.5, cy);
        t.repeat.set(ru, rv);
        t.rotation = rot;
        t.offset.set(offX, offY);
        return new MeshStandardMaterial({ map: t, roughness: 1, metalness: 0 });
      }
      var VR = rimH / VTILE;
      var CT = 'textures/coping.png';
      inline function sideMat(worldStart:Float, len:Float, uDir:Int, cls:String, name:String):MeshStandardMaterial {
        var t = tex.clone();
        t.needsUpdate = true;
        t.wrapS = t.wrapT = THREE.RepeatWrapping;
        t.center.set(0, 1);
        if (uDir > 0) { t.repeat.set(len / tileW, VR); t.offset.set(worldStart / tileW, vOffset); }
        else { t.repeat.set(-len / tileW, VR); t.offset.set((worldStart + len) / tileW, vOffset); }
        return tag(new MeshStandardMaterial({ map: t, roughness: 1, metalness: 0 }), cls, name, CT);
      }
      if (role != null && role.post) {
        var x0 = role.cx - w / 2, z0 = role.cz - d / 2;
        var P = '$prefix-side-post', N = '$label side (corner)';
        var px = sideMat(z0, d, -1, P, N), nx = sideMat(z0, d, 1, P, N);
        var pz = sideMat(x0, w, 1, P, N), nz = sideMat(x0, w, -1, P, N);
        var top = tag(mat(slice, slice), '$prefix-top', '$label top', CT);
        return [px, nx, top, top, pz, nz];
      }
      var isX = w >= d;
      var end = tag(mat(slice, 1), '$prefix-end', '$label end', CT);
      var flatT = tex.clone();
      flatT.needsUpdate = true;
      flatT.wrapS = flatT.wrapT = THREE.RepeatWrapping;
      if (isX) {
        var x0 = role.cx - w / 2;
        flatT.center.set(0, 0.5); flatT.rotation = 0;
        flatT.repeat.set(w / tileW, slice); flatT.offset.set(x0 / tileW, 0);
      } else {
        // py face V runs along -z, so the rotated joint axis is reversed: negative
        // repeat + start at z0+d makes U = worldZ/tileW (matches the x-side lip grid)
        var z0 = role.cz - d / 2;
        flatT.center.set(0, 0); flatT.rotation = Math.PI / 2;
        flatT.repeat.set(-d / tileW, slice); flatT.offset.set((z0 + d) / tileW, 0.5 + slice / 2);
      }
      var flat = tag(new MeshStandardMaterial({ map: flatT, roughness: 1, metalness: 0 }), '$prefix-top', '$label top', CT);
      if (isX) {
        var x0 = role.cx - w / 2;
        var io0 = role.outDir == 0 ? 'out' : 'in', io1 = role.outDir == 1 ? 'out' : 'in';
        var pz = sideMat(x0, w, 1, '$prefix-side-z-$io0', '$label side z $io0');
        var nz = sideMat(x0, w, -1, '$prefix-side-z-$io1', '$label side z $io1');
        return [end, end, flat, flat, pz, nz];
      }
      var z0 = role.cz - d / 2;
      var io2 = role.outDir == 2 ? 'out' : 'in', io3 = role.outDir == 3 ? 'out' : 'in';
      var px = sideMat(z0, d, -1, '$prefix-side-x-$io2', '$label side x $io2');
      var nx = sideMat(z0, d, 1, '$prefix-side-x-$io3', '$label side x $io3');
      return [px, nx, flat, flat, end, end];
    };
  }

  // brick parapet: the wall texture continuing up at a uniform world scale. each
  // face picks worn vs clean to match the wall under it, so a corner post can be
  // worn on its alley side and clean on its street side
  static function brickMats(b:Building, clean:Texture, worn:Texture):(Float, Float, Float, Role) -> Array<MeshStandardMaterial> {
    var c = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
    return function(w:Float, h:Float, d:Float, role:Role):Array<MeshStandardMaterial> {
      inline function rep(m:Float):Float { var r = m / RenderConfig.WALL_TILE; return r >= 1 ? Math.round(r) : r; }
      inline function faceMat(dir:Int, ru:Float, rv:Float):MeshStandardMaterial {
        var wn = dir >= 0 && Geom.isWornFace(b, dir);
        var t = (wn ? worn : clean).clone();
        t.needsUpdate = true;
        t.repeat.set(ru, rv);
        var nm = RenderConfig.FACADE_NAMES[b.facade];
        return tag(new MeshStandardMaterial({ map: t, roughness: 1, metalness: 0 }),
          wn ? 'parapet-$nm-worn' : 'parapet-$nm', wn ? '$nm parapet (worn)' : '$nm parapet',
          (wn ? RenderConfig.TEXTURES.wornWalls : RenderConfig.TEXTURES.walls)[b.facade]);
      }
      // x-faces span z×h, z-faces span w×h; posts use each face's own direction,
      // rims share one outward direction across all faces
      var dirX = role == null ? -1 : (role.post ? (role.cx > c.x ? 2 : 3) : role.outDir);
      var dirZ = role == null ? -1 : (role.post ? (role.cz > c.z ? 0 : 1) : role.outDir);
      var xf = faceMat(dirX, rep(d), rep(h));
      var yf = faceMat(role != null && role.post ? -1 : (role == null ? -1 : role.outDir), rep(w), rep(d));
      var zf = faceMat(dirZ, rep(w), rep(h));
      return [xf, xf, yf, yf, zf, zf];
    };
  }

  // drop a coping block over each concave (T/L) junction corner so the two strips'
  // staggered edge caps read as one clean tile. `along`/`across` are the block size
  // along vs across the resuming edge; `inset` shifts its centre inward from the
  // corner point. raised a hair to win the depth test. shared by brick + concrete
  static function copingCorners(scene:Scene, tex:Texture, covered:Array<Array<{a:Float, b:Float}>>,
      bxMin:Float, bxMax:Float, bzMin:Float, bzMax:Float, capY:Float, capBoxH:Float,
      along:Float, across:Float, inset:Float):Void {
    inline function block(bx:Float, bz:Float, bw:Float, bd:Float) {
      var role:Role = { post: true, outDir: -1, cx: bx, cz: bz };
      var geo = new BoxGeometry(bw, capBoxH, bd);
      var mats:Array<Dynamic> = cast copingMats(tex, 8, 0, 'coping-cap', 'cap coping')(bw, capBoxH, bd, role);
      // single coping texture -> collapse the cap block to one draw call
      var single = render.Poly.flattenBox(geo, mats, 'coping-cap', 'cap coping', 'textures/coping.png');
      var m = new Mesh(geo, single != null ? single : mats);
      m.position.set(bx, capY + 0.004, bz);
      scene.add(m);
    }
    // covered[0]/[1] run along x (block centred on the z edge line); [2]/[3] along z
    for (iv in covered[0]) {
      if (iv.a > bxMin + 1e-4) block(iv.a + inset, bzMax, along, across);
      if (iv.b < bxMax - 1e-4) block(iv.b - inset, bzMax, along, across);
    }
    for (iv in covered[1]) {
      if (iv.a > bxMin + 1e-4) block(iv.a + inset, bzMin, along, across);
      if (iv.b < bxMax - 1e-4) block(iv.b - inset, bzMin, along, across);
    }
    for (iv in covered[2]) {
      if (iv.a > bzMin + 1e-4) block(bxMax, iv.a + inset, across, along);
      if (iv.b < bzMax - 1e-4) block(bxMax, iv.b - inset, across, along);
    }
    for (iv in covered[3]) {
      if (iv.a > bzMin + 1e-4) block(bxMin, iv.a + inset, across, along);
      if (iv.b < bzMax - 1e-4) block(bxMin, iv.b - inset, across, along);
    }
  }

  public static function addParapet(scene:Scene, b:Building, center:{x:Float, z:Float}, wWorld:Float, dWorld:Float, copingTex:Texture, clean:Texture, worn:Texture, masonry:Bool):Void {
    var T = RenderConfig.PARAPET_T;
    var covered = Geom.coveredEdges(b);
    var bxMin = center.x - wWorld / 2, bxMax = center.x + wWorld / 2;
    var bzMin = center.z - dWorld / 2, bzMax = center.z + dWorld / 2;
    if (!masonry) {
      var h = RenderConfig.PARAPET_H, embed = RenderConfig.PARAPET_EMBED, E = 0.12;
      var capY = b.h + h / 2 - embed / 2, capBoxH = h + embed;
      // single coping ring, width T+2E centred on the wall line, with corner posts
      // landing exactly on the wall corners. drop the rim where a same-height
      // neighbour abuts (T/L junction); extend=0 so the rim stops at the cut (no
      // overshoot). the terminating building's own corner post already fills the
      // concave corner — no patch block needed (unlike brick, whose cap posts inset)
      parapetRing(scene, b, center.x, center.z, wWorld / 2 + T / 2 + E, dWorld / 2 + T / 2 + E,
        capY, capBoxH, copingMats(copingTex, 8, 0.0), T + 2 * E, covered, 0);
      return;
    }
    var H = RenderConfig.PARAPET_H_BRICK;
    parapetRing(scene, b, center.x, center.z, wWorld / 2, dWorld / 2, b.h + H / 2, H, brickMats(b, clean, worn), null, covered);
    var capH = 0.3, capEmbed = 0.18, E = 0.08;
    parapetRing(scene, b, center.x, center.z, wWorld / 2 + E, dWorld / 2 + E,
      b.h + H + capH / 2 - capEmbed / 2, capH + capEmbed,
      copingMats(copingTex, 8, 0, 'coping-cap', 'brick cap coping'), T + 2 * E, covered);

    // concave-corner coping: at a T/L junction the two strips' edge caps are inset
    // toward opposite centres, so they sit on opposite sides of the shared edge
    // line and only touch at the corner (a stagger). one block over each such
    // corner — spanning both caps' footprints — reads as a single clean tile
    var capY = b.h + H + capH / 2 - capEmbed / 2, capBoxH = capH + capEmbed;
    var ACROSS = 2 * (T + E), ALONG = T + 2 * E; // across edge / along edge
    copingCorners(scene, copingTex, covered, bxMin, bxMax, bzMin, bzMax, capY, capBoxH, ALONG, ACROSS, T / 2);
  }

  // small pitched gable cap for a stone FRONT-door cover: 2 sloped quads (ridge parallel to the
  // wall, along local x) + 2 triangular gable ends. local frame: x = door width, y up from 0,
  // z out from wall; eaves at z=±cd/2,y=0; ridge at z=0,y=rise. UV world-tiled by `tile`.
  public static function coverGableGeo(cw:Float, cd:Float, rise:Float, tile:Float):BufferGeometry {
    var hw = cw / 2, hd = cd / 2;
    var L = Math.sqrt(hd * hd + rise * rise) / tile; // eave→ridge tile span
    var p = new Array<Float>(), u = new Array<Float>();
    inline function v(x:Float, y:Float, z:Float, tu:Float, tv:Float):Void {
      p.push(x); p.push(y); p.push(z); u.push(tu); u.push(tv);
    }
    // front slope (+z)
    v(-hw, 0, hd, -hw / tile, 0); v(hw, 0, hd, hw / tile, 0); v(hw, rise, 0, hw / tile, L);
    v(-hw, 0, hd, -hw / tile, 0); v(hw, rise, 0, hw / tile, L); v(-hw, rise, 0, -hw / tile, L);
    // back slope (-z)
    v(hw, 0, -hd, hw / tile, 0); v(-hw, 0, -hd, -hw / tile, 0); v(-hw, rise, 0, -hw / tile, L);
    v(hw, 0, -hd, hw / tile, 0); v(-hw, rise, 0, -hw / tile, L); v(hw, rise, 0, hw / tile, L);
    // gable end +x
    v(hw, 0, hd, hd / tile, 0); v(hw, 0, -hd, -hd / tile, 0); v(hw, rise, 0, 0, rise / tile);
    // gable end -x
    v(-hw, 0, -hd, -hd / tile, 0); v(-hw, 0, hd, hd / tile, 0); v(-hw, rise, 0, 0, rise / tile);
    var geo = new BufferGeometry();
    geo.setAttribute('position', new Float32BufferAttribute(p, 3));
    geo.setAttribute('uv', new Float32BufferAttribute(u, 2));
    geo.computeVertexNormals();
    return geo;
  }

  // metal warehouse gable ("double slope") roof: a prism of 2 sloped quads + 2 triangular
  // gable ends, capping the box. ridge runs along the LONGER footprint axis. the SLOPES use a
  // dedicated metal-roof texture; the vertical gable-END triangles are wall (clean or worn to
  // match the wall below — a worn back wall gets a worn gable end). world-tiled (no stretch),
  // ridges run down-slope. only for simple-rectangle metal buildings. DoubleSide so winding
  // never hides a face. the box's own flat top stays, hidden beneath the slopes.
  public static function addGableRoof(scene:Scene, b:Building, center:{x:Float, z:Float}, wWorld:Float, dWorld:Float, cleanWall:Texture, wornWall:Texture, roofTex:Texture):Void {
    var TILE = RenderConfig.WALL_TILE;
    var gV = RenderConfig.GABLE_V; // gable ends sample a CLEAN mid-texture V band (worn metal has a dirty base strip; eaves up high shouldn't show ground grime). ribs are vertical so V-shift keeps corrugation aligned.
    var eaveY = b.h;
    var bxMin = center.x - wWorld / 2, bxMax = center.x + wWorld / 2;
    var bzMin = center.z - dWorld / 2, bzMax = center.z + dWorld / 2;
    var sP = new Array<Float>(), sU = new Array<Float>();   // slopes (roof texture)
    var aP = new Array<Float>(), aU = new Array<Float>();   // gable end A
    var bP = new Array<Float>(), bU = new Array<Float>();   // gable end B
    inline function v(p:Array<Float>, u:Array<Float>, x:Float, y:Float, z:Float, tu:Float, tv:Float):Void {
      p.push(x); p.push(y); p.push(z); u.push(tu); u.push(tv);
    }
    var aDir = 0, bDir = 0;

    if (wWorld >= dWorld) {
      // ridge along X (z = center.z); slopes face ±z, gable ends at ±x
      var cz = center.z;
      var pitchH = Math.min(dWorld * 0.22, 2.6); // shallow gable (~18-20°)
      var ridgeY = eaveY + pitchH;
      var sV = Math.sqrt((dWorld / 2) * (dWorld / 2) + pitchH * pitchH) / TILE; // down-slope tile span
      v(sP, sU, bxMin, eaveY, bzMax, bxMin / TILE, 0); v(sP, sU, bxMax, eaveY, bzMax, bxMax / TILE, 0); v(sP, sU, bxMax, ridgeY, cz, bxMax / TILE, sV);
      v(sP, sU, bxMin, eaveY, bzMax, bxMin / TILE, 0); v(sP, sU, bxMax, ridgeY, cz, bxMax / TILE, sV); v(sP, sU, bxMin, ridgeY, cz, bxMin / TILE, sV);
      v(sP, sU, bxMax, eaveY, bzMin, bxMax / TILE, 0); v(sP, sU, bxMin, eaveY, bzMin, bxMin / TILE, 0); v(sP, sU, bxMin, ridgeY, cz, bxMin / TILE, sV);
      v(sP, sU, bxMax, eaveY, bzMin, bxMax / TILE, 0); v(sP, sU, bxMin, ridgeY, cz, bxMin / TILE, sV); v(sP, sU, bxMax, ridgeY, cz, bxMax / TILE, sV);
      // gable ends (vertical triangles), uv by world z (along) × height
      aDir = 2; v(aP, aU, bxMax, eaveY, bzMax, bzMax / TILE, gV); v(aP, aU, bxMax, eaveY, bzMin, bzMin / TILE, gV); v(aP, aU, bxMax, ridgeY, cz, cz / TILE, gV + pitchH / TILE);
      bDir = 3; v(bP, bU, bxMin, eaveY, bzMin, bzMin / TILE, gV); v(bP, bU, bxMin, eaveY, bzMax, bzMax / TILE, gV); v(bP, bU, bxMin, ridgeY, cz, cz / TILE, gV + pitchH / TILE);
    } else {
      // ridge along Z (x = center.x); slopes face ±x, gable ends at ±z
      var cx = center.x;
      var pitchH = Math.min(wWorld * 0.22, 2.6); // shallow gable (~18-20°)
      var ridgeY = eaveY + pitchH;
      var sV = Math.sqrt((wWorld / 2) * (wWorld / 2) + pitchH * pitchH) / TILE;
      v(sP, sU, bxMax, eaveY, bzMin, bzMin / TILE, 0); v(sP, sU, bxMax, eaveY, bzMax, bzMax / TILE, 0); v(sP, sU, cx, ridgeY, bzMax, bzMax / TILE, sV);
      v(sP, sU, bxMax, eaveY, bzMin, bzMin / TILE, 0); v(sP, sU, cx, ridgeY, bzMax, bzMax / TILE, sV); v(sP, sU, cx, ridgeY, bzMin, bzMin / TILE, sV);
      v(sP, sU, bxMin, eaveY, bzMax, bzMax / TILE, 0); v(sP, sU, bxMin, eaveY, bzMin, bzMin / TILE, 0); v(sP, sU, cx, ridgeY, bzMin, bzMin / TILE, sV);
      v(sP, sU, bxMin, eaveY, bzMax, bzMax / TILE, 0); v(sP, sU, cx, ridgeY, bzMin, bzMin / TILE, sV); v(sP, sU, cx, ridgeY, bzMax, bzMax / TILE, sV);
      // gable ends, uv by world x (along) × height
      aDir = 0; v(aP, aU, bxMax, eaveY, bzMax, bxMax / TILE, gV); v(aP, aU, bxMin, eaveY, bzMax, bxMin / TILE, gV); v(aP, aU, cx, ridgeY, bzMax, cx / TILE, gV + pitchH / TILE);
      bDir = 1; v(bP, bU, bxMin, eaveY, bzMin, bxMin / TILE, gV); v(bP, bU, bxMax, eaveY, bzMin, bxMax / TILE, gV); v(bP, bU, cx, ridgeY, bzMin, cx / TILE, gV + pitchH / TILE);
    }

    inline function mesh(p:Array<Float>, u:Array<Float>, tex:Texture, nm:String, desc:String, path:String):Void {
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(p, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(u, 2));
      geo.computeVertexNormals();
      var t = tex.clone(); t.needsUpdate = true; t.wrapS = t.wrapT = THREE.RepeatWrapping;
      var m = tag(new MeshStandardMaterial({ map: t, roughness: 1, metalness: 0, side: THREE.DoubleSide }), nm, desc, path);
      // geometry is baked in world coords (mesh stays at origin), so tag the building
      // explicitly — Occlusion's position bucketing can't place an origin-anchored mesh
      var mesh = new Mesh(geo, m);
      mesh.userData.b = b;
      scene.add(mesh);
    }
    mesh(sP, sU, roofTex, 'roof-gable-metal', 'metal gable roof', RenderConfig.TEXTURES.roofMetal);
    var aWorn = Geom.isWornFace(b, aDir), bWorn = Geom.isWornFace(b, bDir);
    mesh(aP, aU, aWorn ? wornWall : cleanWall, 'gable-end-metal' + (aWorn ? '-worn' : ''), 'metal gable end' + (aWorn ? ' (worn)' : ''), RenderConfig.TEXTURES.walls[3]);
    mesh(bP, bU, bWorn ? wornWall : cleanWall, 'gable-end-metal' + (bWorn ? '-worn' : ''), 'metal gable end' + (bWorn ? ' (worn)' : ''), RenderConfig.TEXTURES.walls[3]);
  }

  // fake contact shadow under the parapet: instanced gradient decals on the roof
  public static function addRoofShadows(scene:Scene):Void {
    var buildings = WorldCtx.buildings;
    var geo = new PlaneGeometry(1, 1);
    inline function mkMat(alphaMap:Texture):MeshBasicMaterial return new MeshBasicMaterial({
      color: 0x000000, alphaMap: alphaMap, transparent: true, opacity: RenderConfig.ROOF_SHADOW_ALPHA,
      depthWrite: false, side: THREE.DoubleSide });
    var q = new Quaternion();
    var qx = new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), -Math.PI / 2);
    var up = new Vector3(0, 1, 0);
    var pos = new Vector3();
    var scl = new Vector3();
    var W = RenderConfig.ROOF_SHADOW_W;
    var CW = W * 1.7;
    var OV = 0;
    var edgeM:Array<Matrix4> = [];
    var cornM:Array<Matrix4> = [];
    inline function push(arr:Array<Matrix4>, len1:Float, len2:Float, yaw:Float, px:Float, py:Float, pz:Float) {
      q.setFromAxisAngle(up, yaw).multiply(qx);
      pos.set(px, py, pz);
      scl.set(len1, len2, 1);
      arr.push(new Matrix4().compose(pos, q, scl));
    }
    for (b in buildings) {
      if (b.facade == 3) continue; // metal warehouses have a gable roof, not a flat parapet roof
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      var y = b.h + 0.03;
      var offX = wWorld / 2 - RenderConfig.PARAPET_T / 2 + OV;
      var offZ = dWorld / 2 - RenderConfig.PARAPET_T / 2 + OV;
      // skip shadow where the parapet was removed at a same-height junction, else
      // a contact-shadow band lingers on the roof with no wall to cast it
      var covered = Geom.coveredEdges(b);
      var bxMin = center.x - wWorld / 2, bxMax = center.x + wWorld / 2;
      var bzMin = center.z - dWorld / 2, bzMax = center.z + dWorld / 2;
      // shadow follows wall: edge bands only on exposed (parapet-bearing) spans, cut
      // at same-height seams where the parapet — and so its shadow — was removed
      for (seg in Geom.exposedSpans(covered, 0, bxMin, bxMax, 0)) push(edgeM, seg.b - seg.a, W, 0, (seg.a + seg.b) / 2, y, center.z + offZ - W / 2);
      for (seg in Geom.exposedSpans(covered, 1, bxMin, bxMax, 0)) push(edgeM, seg.b - seg.a, W, Math.PI, (seg.a + seg.b) / 2, y, center.z - offZ + W / 2);
      for (seg in Geom.exposedSpans(covered, 2, bzMin, bzMax, 0)) push(edgeM, seg.b - seg.a, W, Math.PI / 2, center.x + offX - W / 2, y, (seg.a + seg.b) / 2);
      for (seg in Geom.exposedSpans(covered, 3, bzMin, bzMax, 0)) push(edgeM, seg.b - seg.a, W, -Math.PI / 2, center.x - offX + W / 2, y, (seg.a + seg.b) / 2);
      // convex corner radials — only at real outline corners. skip any corner whose
      // adjacent edge is covered there (a junction/colinear point, no two walls meet)
      function coveredAt(dir:Int, coord:Float):Bool {
        for (iv in covered[dir]) if (iv.a - 1e-4 <= coord && coord <= iv.b + 1e-4) return true;
        return false;
      }
      var SR = W * 0.7; // concave radials a touch smaller than the band so they never overgrow it
      inline function concave(px:Float, pz:Float, nsx:Float, nsz:Float) {
        var yaw = nsx > 0 ? (nsz > 0 ? 0.0 : Math.PI / 2) : (nsz > 0 ? -Math.PI / 2 : Math.PI);
        push(cornM, SR, SR, yaw, px - nsx * SR / 2, y, pz - nsz * SR / 2);
      }
      // per outline corner: outward diagonal void (else buried → skip). both edges
      // exposed → real convex corner. both edges covered but the diagonal still open →
      // a reentrant corner where the void is only the diagonal notch (e.g. a + centre,
      // fully ringed by arms); its two interior walls meet here → concave radial. one
      // edge covered → a colinear straight point, no radial
      var corners:Array<Array<Float>> = [[1, 1, 0], [1, -1, Math.PI / 2], [-1, -1, Math.PI], [-1, 1, -Math.PI / 2]];
      for (cdef in corners) {
        var sx = cdef[0], sz = cdef[1], yaw = cdef[2];
        var cornerX = center.x + sx * wWorld / 2, cornerZ = center.z + sz * dWorld / 2;
        if (Geom.cornerBuried(b, cornerX, cornerZ, sx, sz)) continue;
        var ec0 = coveredAt(sz > 0 ? 0 : 1, cornerX), ec1 = coveredAt(sx > 0 ? 2 : 3, cornerZ);
        if (!ec0 && !ec1) push(cornM, CW, CW, yaw, center.x + sx * (offX - CW / 2), y, center.z + sz * (offZ - CW / 2));
        else if (ec0 && ec1) concave(cornerX, cornerZ, sx, sz);
      }
      // reentrant corner at the interior end of a covered span (an L/T tip), where two
      // exposed perimeter walls meet at an inside corner — fill that nook
      for (iv in covered[0]) { if (iv.a > bxMin + 1e-4) concave(iv.a, bzMax, -1, 1); if (iv.b < bxMax - 1e-4) concave(iv.b, bzMax, 1, 1); }
      for (iv in covered[1]) { if (iv.a > bxMin + 1e-4) concave(iv.a, bzMin, -1, -1); if (iv.b < bxMax - 1e-4) concave(iv.b, bzMin, 1, -1); }
      for (iv in covered[2]) { if (iv.a > bzMin + 1e-4) concave(bxMax, iv.a, 1, -1); if (iv.b < bzMax - 1e-4) concave(bxMax, iv.b, 1, 1); }
      for (iv in covered[3]) { if (iv.a > bzMin + 1e-4) concave(bxMin, iv.a, -1, -1); if (iv.b < bzMax - 1e-4) concave(bxMin, iv.b, -1, 1); }
    }
    var sets = [{ mats: edgeM, tex: Textures.makeShadowGradient() }, { mats: cornM, tex: Textures.makeRadialShadowGradient() }];
    for (s in sets) {
      var mesh = new InstancedMesh(geo, mkMat(s.tex), s.mats.length);
      for (k in 0...s.mats.length) mesh.setMatrixAt(k, s.mats[k]);
      mesh.instanceMatrix.needsUpdate = true;
      scene.add(mesh);
    }
  }

  // roof details: a top-down sprite decal per sector, instanced per type
  public static function addRoofDetails(scene:Scene):Void {
    var buildings = WorldCtx.buildings;
    var sprites = [for (t in DETAIL_TYPES) Textures.loadKeyedTexture(t.tex, t.crop, RenderConfig.DETAIL_BOX_COLOR)];
    // one material per detail type, shared by every building: only `map` differs between types, so
    // allocating per building left ~750 identical materials live citywide where 6 do the same job
    var mats = [for (t in 0...DETAIL_TYPES.length) new MeshStandardMaterial({
      map: sprites[t],
      roughness: 1,
      metalness: 0,
      transparent: false,
      alphaTest: 0.5,
      side: THREE.DoubleSide,
    })];
    var q = new Quaternion();
    var qx = new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), -Math.PI / 2);
    var up = new Vector3(0, 1, 0);
    var pos = new Vector3();
    var scl = new Vector3();
    var decalGeo = new PlaneGeometry(1, 1);

    for (b in buildings) {
      if (b.facade == 3) continue; // metal warehouses have a gable roof — no rooftop details
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var hx = wWorld / 2 - RenderConfig.ROOF_DETAIL_MARGIN;
      var hz = dWorld / 2 - RenderConfig.ROOF_DETAIL_MARGIN;
      if (hx <= 0 || hz <= 0) continue;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);

      var cols = Std.int(imax(1, Math.round((2 * hx) / RenderConfig.ROOF_SECTOR)));
      var rows = Std.int(imax(1, Math.round((2 * hz) / RenderConfig.ROOF_SECTOR)));
      while (cols * rows > RenderConfig.DETAIL_MAX) { if (cols >= rows) cols--; else rows--; }
      var secW = (2 * hx) / cols;
      var secD = (2 * hz) / rows;

      var order = [for (i in 0...DETAIL_TYPES.length) i];
      var i = order.length - 1;
      while (i > 0) {
        var j = Std.int(Math.random() * (i + 1));
        var tmp = order[i]; order[i] = order[j]; order[j] = tmp;
        i--;
      }
      // per-building matrices, grouped by detail type
      var decalM:Array<Array<Matrix4>> = [for (t in DETAIL_TYPES) []];
      var pick = 0;
      for (ci in 0...cols) {
        for (cj in 0...rows) {
          var t = order[(pick++) % order.length];
          var type = DETAIL_TYPES[t];
          var yaw = Std.int(Math.random() * 4) * (Math.PI / 2);
          var x = center.x - hx + (ci + 0.5) * secW;
          var z = center.z - hz + (cj + 0.5) * secD;
          q.setFromAxisAngle(up, yaw).multiply(qx);
          pos.set(x, b.h + 0.05, z);
          scl.set(type.w, type.d, 1);
          decalM[t].push(new Matrix4().compose(pos, q, scl));
        }
      }
      // one instanced mesh per used type, tagged with the building so Occlusion fades them too
      for (t in 0...DETAIL_TYPES.length) {
        if (decalM[t].length == 0) continue;
        var decals = new InstancedMesh(decalGeo, mats[t], decalM[t].length);
        for (k in 0...decalM[t].length) decals.setMatrixAt(k, decalM[t][k]);
        decals.instanceMatrix.needsUpdate = true;
        decals.userData.b = b;
        scene.add(decals);
      }
    }
  }
}
