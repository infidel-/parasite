package render.world.roofs;

import three.Three;
import citygen.CityConfig.cellToWorld;
import citygen.CityModel.Building;
import render.RenderConfig;
import render.Poly.tag;
import render.world.Geom;
import render.world.WorldCtx;

typedef Role = { post:Bool, outDir:Int, cx:Float, cz:Float };

// parapet rings and their coping: the 4-post + 4-rim ring, the world-tiled coping face
// materials (shared with the downtown flat roof in FlatRoofs), the brick parapet face
// materials, and the concave-corner cap blocks at T/L junctions. Edge coverage / worn-face
// classification comes from Geom.
class Parapets {
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
  public static function copingMats(tex:Texture, tileW:Float, vOffset:Float = 0, prefix:String = 'coping', label:String = 'parapet coping')
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
        // style-driven, and wrapped: a style may declare more facade slots than the residential
        // naming/texture arrays hold, and these were indexing both of them raw
        var st = WorldCtx.style;
        var nm = st.facadeName(b.facade);
        var paths = wn ? st.wornWalls : st.walls;
        return tag(new MeshStandardMaterial({ map: t, roughness: 1, metalness: 0 }),
          wn ? 'parapet-$nm-worn' : 'parapet-$nm', wn ? '$nm parapet (worn)' : '$nm parapet',
          paths[b.facade % paths.length]);
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
}
