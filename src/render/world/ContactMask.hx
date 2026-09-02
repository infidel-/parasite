package render.world;

import js.Browser;
import three.Three;
import citygen.CityConfig;
import render.world.ContactMaskOpts;

// the CONTACT MASK: a blurred top-down picture of where the masonry is, sampled by world XZ inside
// the floor materials and used to darken the floor as it approaches a wall. the fake ambient
// occlusion the tunnels and the streets get from render.sewer.SewerDetail and RoofShadows, done as a
// FIELD instead of as quads.
//
// THE OBITUARY IS THE POINT OF THIS HEADER, because the quad version was built first and shipped
// broken. Both of those files lay one gradient quad per wall FACE, `CELL` long, and that works where
// a wall face IS the cell boundary. A facility wall is a SLAB: FacilityGeom.slab insets by
// (CELL - thick)/2 on every side the wall line does not carry into, so per-cell strips do not tile.
// Measured on the built compound by counting how many strips covered each sample point along one
// straight run: `111...1111211132` — a GAP wherever a slab insets, and a DOUBLE or TRIPLE wherever a
// notch adds its own. A quad's alpha is uniform along its run, so every one of those count changes
// is a hard edge, and they were reported from the game as missing corners and lines beside doors.
// The corners and the doors were only where it showed first; the band was discontinuous everywhere.
//
// a blurred field cannot have that class of bug. there are no tiles to fail to meet, so corners,
// doorways, slab insets, notches, T-junctions and the hangar all come out of one blur with nothing
// special written for any of them. two more things fall out, exactly as they do for IndoorMask:
//   IT COSTS NO DRAW CALL. one texture fetch folded into materials that already draw, where the quad
//     version was one InstancedMesh and one more program.
//   THE FALLOFF IS ONE NUMBER. opt.blur is the entire reach; there is no gradient texture to author
//     and no per-case radial or end-fade to add later.
//
// what it deliberately does NOT do is darken a WALL. the mask is top-down, so every fragment of a
// 6-unit wall face samples the same xz and the whole column would darken by the same amount. only
// the three interior floors take it — see render.facility.FacilityGeom.addFloor
class ContactMask
{
  // the live tuning, and whether an area attached one at all. static for the reason VisionMask's and
  // IndoorMask's are: exactly one area is ever built
  static var opt:ContactMaskOpts = null;
  public static var on(default, null):Bool = false;

  static var canvas:js.html.CanvasElement = null;
  static var tex:CanvasTexture = null;
  // the unattached stand-in: one black texel, which reads as occlusion 0 and makes the whole
  // injection an exact no-op rather than something to branch around
  static var blank:CanvasTexture = null;

  // the uniform blocks every patched material references BY IDENTITY — three keeps the reference it
  // is handed in onBeforeCompile, so writing .value here reaches every material at once. same idiom,
  // and same reason, as VisionMask's and IndoorMask's own
  static var uMap:Dynamic = { value: null };
  static var uScale:Dynamic = { value: new Vector2(0, 0) };
  static var uOrigin:Dynamic = { value: new Vector2(0, 0) };
  static var uAmt:Dynamic = { value: 0.0 };

  // how many rectangles the last paint drew, for __facility()
  public static var count(default, null) = 0;

// bind the mask to an area, painting it from the masonry footprint.
//
// CALL THIS BEFORE THE AREA'S BUILDERS RUN, the same ordering IndoorMask.attach needs and for the
// same reason: `on` is read by patch() at MATERIAL-CREATION time to decide whether to inject at all.
//
// `solid` is the masonry and `holes` is what the masonry does NOT hold inside it — for a facility,
// the slab boxes and then the corner notches, because a wall cell is the union of its runs and never
// its bounding box. they are painted in that order, so a hole always wins over the solid it sits in
  public static function attach(o:ContactMaskOpts, w:Int, h:Int, solid:Array<ContactRect>,
      holes:Array<ContactRect>):Void
    {
      opt = o;
      on = true;
      paint(w, h, solid, holes);
      uMap.value = tex;
      uAmt.value = o.strength;
      count = solid.length;
    }

// release it. every OTHER area kind runs through this, so a facility exit cannot leave the sewer
// sampling the last compound's floor plan
  public static function detach():Void
    {
      opt = null;
      on = false;
      uMap.value = ensureBlank();
      uAmt.value = 0.0;
      count = 0;
    }

// paint the mask and upload it. white where the masonry stands, blurred outward, and the blur IS the
// contact shadow — there is no second gradient anywhere in this file.
//
// the rects arrive in WORLD xz and the canvas is indexed in cells, which is the one conversion here:
// FacilityGeom builds every rect off `col * CELL - half`, so a world x is (x + half) / CELL cells and
// that times opt.px is the texel. NOTHING is grown or inset on the way in — the whole point of taking
// rects rather than a per-cell predicate is that the masonry's real edge is what gets blurred
  static function paint(w:Int, h:Int, solid:Array<ContactRect>, holes:Array<ContactRect>):Void
    {
      var P = opt.px;
      var half = (CityConfig.GRID * CityConfig.CELL) / 2;
      var src = Browser.document.createCanvasElement();
      src.width = w * P;
      src.height = h * P;
      var c = src.getContext2d();
      // opaque black rather than a cleared canvas: the mask is read as a plain channel value, and
      // leaving alpha in play only invites the browser to premultiply the blur into it
      c.fillStyle = '#000000';
      c.fillRect(0, 0, src.width, src.height);
      inline function rect(r:ContactRect):Void
        c.fillRect((r.x0 + half) / CityConfig.CELL * P, (r.z0 + half) / CityConfig.CELL * P,
          (r.x1 - r.x0) / CityConfig.CELL * P, (r.z1 - r.z0) / CityConfig.CELL * P);
      c.fillStyle = '#ff0000';
      for (r in solid)
        rect(r);
      // and back out again where the masonry is not what the box says. this is why a notch needs no
      // geometry of its own: erasing it from the field puts the blur round the inside corner exactly
      // as it goes round every other edge
      c.fillStyle = '#000000';
      for (r in holes)
        rect(r);
      canvas = Browser.document.createCanvasElement();
      canvas.width = src.width;
      canvas.height = src.height;
      var d = canvas.getContext2d();
      // opt.blur is in WORLD units and the filter wants TEXELS — converted here, so changing opt.px
      // never silently rescales the falloff with it
      d.filter = 'blur(' + (opt.blur * P / CityConfig.CELL) + 'px)';
      d.drawImage(src, 0, 0);
      d.filter = 'none';
      tex = new CanvasTexture(canvas);
      // DATA, not colour, and the same four settings VisionMask.ensure and IndoorMask.paint land on:
      // an sRGB decode would bend the ramp, v has to run with the row index, and a mip chain would
      // both cost a regeneration and over-blur an edge at the grazing angles these cameras live at
      tex.colorSpace = THREE.NoColorSpace;
      tex.flipY = false;
      tex.generateMipmaps = false;
      tex.minFilter = THREE.LinearFilter;
      tex.magFilter = THREE.LinearFilter;
      // world XZ -> uv, resolution-independent: opt.px changes how finely the ramp is sampled and
      // nothing here
      uScale.value.set(1 / (CityConfig.CELL * w), 1 / (CityConfig.CELL * h));
      uOrigin.value.set(CityConfig.GRID / 2 / w, CityConfig.GRID / 2 / h);
    }

// the one black texel, built once
  static function ensureBlank():CanvasTexture
    {
      if (blank != null)
        return blank;
      var e = Browser.document.createCanvasElement();
      e.width = 1;
      e.height = 1;
      var c = e.getContext2d();
      c.fillStyle = '#000000';
      c.fillRect(0, 0, 1, 1);
      blank = new CanvasTexture(e);
      blank.colorSpace = THREE.NoColorSpace;
      blank.generateMipmaps = false;
      blank.minFilter = THREE.LinearFilter;
      blank.magFilter = THREE.LinearFilter;
      return blank;
    }

// fold the darkening into one material, and hand it back so a builder can wrap it around the
// material it was already constructing.
//
// GATED AT THE CALL SITE, exactly as IndoorMask is: only render.facility.FacilityGeom.addFloor calls
// this, so every other surface in every area kind compiles the shader it compiles today and pays
// nothing.
//
// THIS PATCH REQUIRES A VisionMask PATCH ON THE SAME MATERIAL, APPLIED AFTER IT. It reads
// `visMaskRaw`, the global VisionMask declares and assigns, and without one the shader will not
// compile. render.facility.FacilityGeom.addFloor is the only caller and pairs them in that order.
//
// IT DARKENS gl_FragColor AT <fog_fragment>, AND THE FIRST VERSION GOT THIS WRONG. That one scaled
// `irradiance` up at <lights_fragment_end>, which is upstream of VisionMask — and VisionMask does not
// darken a hidden surface, it MIXES IT TOWARD THE FOG COLOUR so that the hidden region carries no
// silhouette of its own (its header says exactly that). A term applied upstream therefore survives
// into the veil at the floor weight, 0.14, and printed the wall footprint through it as blotches:
// reported from the game as holes in the LOS shadow. Any effect that must not be seen through the
// mask has to be applied at or after this anchor, keyed on the mask.
//
// THE KEY IS `visMaskRaw` AND NOT `visAmt`. visAmt is floored at visMaskFloor and bottoms out at
// 0.14, so gating on it would leave 14% of the same artefact; the raw term reaches a true zero where
// the player cannot see, which switches this off completely rather than merely dimming it.
//
// ORDERING IS BOUGHT BY THE NESTING, not by the anchor. Both hooks replace <fog_fragment> with itself
// plus their code, so whoever patches FIRST lands LAST in main() — this must patch first for
// VisionMask's assignment to run before this reads it
  public static function patch(mat:Dynamic):Dynamic
    {
      // the "already patched" mark lives on the HOOK and not in userData, for the reason VisionMask
      // carries an obituary for: Material.clone() copies userData but NOT onBeforeCompile, so a
      // userData flag rides onto the ghost clones render.Models makes and locks them out of a patch
      // they never received
      if (mat.onBeforeCompile != null &&
          mat.onBeforeCompile.contactMask == true)
        return mat;
      if (mat.isMeshLambertMaterial != true &&
          mat.isMeshStandardMaterial != true &&
          mat.isMeshPhongMaterial != true)
        return mat;
      var inject =
        '  float coAmt = texture2D( contactMap, vContactXZ * contactScale + contactOrigin ).r;\n' +
        '  gl_FragColor.rgb *= 1.0 - contactAmt * coAmt * visMaskRaw;\n';
      var prev:Dynamic = mat.onBeforeCompile;
      // an OWN key only. three's Material carries a DEFAULT customProgramCacheKey on the PROTOTYPE
      // that returns this.onBeforeCompile.toString(), so the field is never null and taking it
      // blindly would call it unbound on every draw and blank the frame
      var prevKey:Dynamic = untyped mat.hasOwnProperty('customProgramCacheKey') ?
        mat.customProgramCacheKey : null;
      var hook:Dynamic = function(shader:Dynamic, renderer:Dynamic)
        {
          if (prev != null)
            prev(shader, renderer);
          shader.uniforms.contactMap = uMap;
          shader.uniforms.contactScale = uScale;
          shader.uniforms.contactOrigin = uOrigin;
          shader.uniforms.contactAmt = uAmt;
          // the instanceMatrix branch is not optional here either — a floor merged into an instanced
          // batch would otherwise sample whatever stands at the world origin
          shader.vertexShader = 'varying vec2 vContactXZ;\n' +
            StringTools.replace(shader.vertexShader, '#include <project_vertex>',
              '#include <project_vertex>\n' +
              '#ifdef USE_INSTANCING\n' +
              '  vContactXZ = ( modelMatrix * instanceMatrix * vec4( transformed, 1.0 ) ).xz;\n' +
              '#else\n' +
              '  vContactXZ = ( modelMatrix * vec4( transformed, 1.0 ) ).xz;\n' +
              '#endif');
          shader.fragmentShader = 'uniform sampler2D contactMap;\n' +
            'uniform vec2 contactScale;\n' +
            'uniform vec2 contactOrigin;\n' +
            'uniform float contactAmt;\n' +
            'varying vec2 vContactXZ;\n' +
            StringTools.replace(shader.fragmentShader, '#include <fog_fragment>',
              '#include <fog_fragment>\n' + inject);
        };
      // carry forward the marks of whatever hook we just wrapped, so an "already patched" test that
      // can only read the OUTERMOST hook still finds a marker that got chained over
      if (prev != null)
        for (f in Reflect.fields(prev))
          Reflect.setField(hook, f, Reflect.field(prev, f));
      hook.contactMask = true;
      mat.onBeforeCompile = hook;
      // three keys its program cache on base material params, NOT on onBeforeCompile — without a key
      // of our own a darkened program could be handed to an identical plain material. the chained key
      // has to carry the wrapped hook's too
      mat.customProgramCacheKey = function()
        return (prevKey != null ? Std.string(Reflect.callMethod(mat, prevKey, [])) : '') +
          'contact';
      mat.needsUpdate = true;
      if (uMap.value == null)
        uMap.value = ensureBlank();
      return mat;
    }
}
