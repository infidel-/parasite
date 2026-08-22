package render.world;

import three.Three;
import render.RenderConfig;
import render.world.ObjModels.PropShine;
import render.world.ObjModels.PropKey;
import render.world.PropShader.ShaderPatch;

// the grown props' SURFACE GLOW, folded into the material they already draw with. two terms, both
// pure fragment shader, both driven by one shared clock:
//   MASK   — the prop's OWN baked albedo, keyed on a channel RATIO the row picks (PropKey), so only
//            the part of the prop that is supposed to luminesce does. keying on colour rather than on
//            a painted map is not a shortcut: a TRELLIS atlas is a shattered mosaic of tiny charts, so
//            nothing here can be authored in uv space, and a hand-painted emissive map is invalidated
//            the moment the mesh is regenerated (new uvs, so it lights random patches — see
//            docs/3d-changes.md).
//   MOTES  — a few loci travelling a slow helix through the prop's own bounding box. each lights the
//            surface NEAREST to it, so what reads is a speck sliding over the mineral, round the back
//            and up again. this is the term that moves.
//
// the two tunings shipped so far are near opposite ends of what it can do, and both are on one row
// each in ObjModels: the biomineral's are 8 hard specks that clip and bloom on a hard-edged mask, the
// preservator's are 3 huge dim blobs on a deliberately soft one, which reads as light inside a shell
// rather than as anything sitting on it.
//
// a THIRD term was tried and removed: object space quantised into cells, each swelling on a beat of
// its own, as a low shimmer so the crystal was not dead between motes. It read as flat rectangular
// patches — a cube lattice has no relation to where the mesh's own facets actually are, and at any
// amplitude that showed at all, the lattice showed with it.
//
// like render.world.PropShader it costs NO draw call, NO pass and NO geometry: the props stay the same
// instanced batches drawing the same materials, and everything here is arithmetic in a fragment shader
// that was already running. the halo is the composer's existing bloom pass catching an HDR tint — the
// recipe every glowing thing in this game uses.
//
// WHICH props glow is the `shine` column of render.world.ObjModels.MODELS, and a null row is simply
// never patched (so it also keeps the shared unpatched program)
class PropGlow
{
  // the clock every patched material references BY IDENTITY, in BASE_MS units — so per-prop rates are
  // plain multipliers and writing .value here reaches every material at once. its own clock rather
  // than render.world.PropShader's on purpose: a module that silently freezes because a DIFFERENT
  // module stopped being ticked is the kind of coupling that is only ever found the hard way
  static var uTime = { value: 0.0 };

// advance the shared clock. call once per frame from the area kind's tick, BEFORE the patches below
  public static function tick(dtMs:Float):Void
    {
      uTime.value += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
    }

// patch a mesh's material, tolerating a mesh that is not there yet and a prop that does not glow.
// every glb-backed prop arrives through a loader callback, so its InstancedMesh is null for the first
// frames — the same reason render.world.PropShader.patchMesh is called per frame rather than at build
  public static function patchMesh(o:Object3D, s:PropShine):Void
    {
      if (s == null ||
          !RenderConfig.PROP_GLOW.enabled)
        return;
      if (o != null &&
          o.material != null &&
          o.geometry != null)
        patch(o.material, o.geometry, s);
    }

// fold the glow into one material. `geo` is needed as well as the material because every offset and
// radius here is a FRACTION of the prop's own extent rather than a world number: render.Models
// .instanced scales by HEIGHT alone, so a hand-typed constant stops meaning what it said the moment a
// row's `h` is edited (the lesson SewerProp.margin -> `r` already paid for). render.Models.normalize
// recenters a template by moving root.position and instanced() folds that offset into the instance
// matrix analytically, so raw local coordinates are centred on NOTHING and the box has to be read.
// `mat` is Dynamic at a real boundary and not for convenience: three's materials have no base extern
// here (Standard, Basic and Lambert are three unrelated classes in three.Three) and none of them
// declares onBeforeCompile / customProgramCacheKey / needsUpdate. render.world.PropShader carries the
// same note for the same reason
  public static function patch(mat:Dynamic, geo:BufferGeometry, s:PropShine):Void
    {
      // the mark lives on the HOOK and not in userData: Material.clone() copies userData but NOT
      // onBeforeCompile, so a userData flag would ride onto the GHOST clones render.Models makes from
      // a patched template and lock them out of the patch they never received
      if (mat.onBeforeCompile != null &&
          mat.onBeforeCompile.propGlow == true)
        return;
      // totalEmissiveRadiance only exists in a LIT material's fragment shader. the tactical outline
      // hull is a MeshBasicMaterial and has none — and must not glow anyway, it is a UI marker
      if (mat.isMeshStandardMaterial != true)
        return;
      if (geo.boundingBox == null)
        geo.computeBoundingBox();
      var bb = geo.boundingBox;
      var span = bb.max.y - bb.min.y;
      if (span <= 0)
        return;
      var centre = new Vector3((bb.min.x + bb.max.x) * 0.5, bb.min.y, (bb.min.z + bb.max.z) * 0.5);
      var u = {
        centre: { value: centre },
        span: { value: span },
        // HDR: past 1 is what carries the mote peaks over the bloom threshold, the recipe
        // render.TacticalGrid and render.PathLine use. green is the CHEAPEST channel to bloom with —
        // linear luminance weighs it 0.7152 against blue's 0.0722, the trap the cool wall fixtures hit
        color: { value: new Color(s.color).multiplyScalar(s.glow) },
        keyLo: { value: s.keyLo },
        keyHi: { value: s.keyHi },
        base: { value: s.base },
        mote: { value: s.mote },
        moteR: { value: s.moteR },
        r: { value: s.r },
        rTop: { value: s.rTop },
        yLo: { value: s.yLo },
        rise: { value: s.rise },
        spin: { value: s.spin },
        front: { value: s.front },
      };
      var decl =
        'uniform float propGlowTime;\n' +
        'uniform vec3 propGlowCentre;\n' +
        'uniform float propGlowSpan;\n' +
        'uniform vec3 propGlowColor;\n' +
        'uniform float propGlowKeyLo;\n' +
        'uniform float propGlowKeyHi;\n' +
        'uniform float propGlowBase;\n' +
        'uniform float propGlowMote;\n' +
        'uniform float propGlowMoteR;\n' +
        'uniform float propGlowR;\n' +
        'uniform float propGlowRTop;\n' +
        'uniform float propGlowYLo;\n' +
        'uniform float propGlowRise;\n' +
        'uniform float propGlowSpin;\n' +
        'uniform float propGlowFront;\n' +
        'varying vec3 vGlowPos;\n' +
        'varying float vGlowPh;\n' + // ALREADY hashed to 0..1 by the vertex half — see the note there
        'varying float vGlowCam;\n' + // camera azimuth in the INSTANCE's own local frame
        // the standard fract(sin(x) * k) hash, the one render.actors.PropFX rolls its fireflies off.
        // deterministic, so a mote's own speed and start point are the same on every frame and after
        // every reload with nothing stored anywhere. it amplifies its input's error by 43758, so
        // NOTHING with a large magnitude may reach it — that is what vGlowPh's bound is for
        'float propGlowHash( float n )\n' +
        '{\n' +
        '  return fract( sin( n ) * 43758.5453 );\n' +
        '}\n';
      // the glow field is keyed on LOCAL position, never on the map uv: the atlas is a mosaic of tiny
      // charts, so a mote walking uv space would teleport across the model. `position` and not
      // `transformed`, so a prop that also sways keeps its motes glued to the material rather than
      // swimming with the geometry.
      // the per-instance phase is read off the instance TRANSLATION and never off gl_InstanceID:
      // render.Models.cull repacks the surviving instances into the front of the buffer every frame,
      // so a given prop's index changes as the camera moves and an index-keyed phase would jitter.
      //
      // it is HASHED HERE, in the vertex shader, and handed over already reduced to 0..1 — which is
      // not tidiness, it is the whole reason this reads as a glow and not as static. a varying is
      // interpolated at ~24-bit precision, so one carrying raw world coordinates (~50 here) arrives
      // with ~3e-6 of per-fragment error; feed that to fract( sin( n ) * 43758.5453 ) downstream and
      // the hash multiplies the error by 43758, i.e. ~13% of random jitter on EVERY PIXEL. Bounded
      // to 0..1 the same error is ~3e-8 and the amplified jitter is ~1e-3. Measured as dense green
      // speckle over the whole prop, and misdiagnosed twice as the mask band and as the art's grain
      //
// vGlowCam is where the CAMERA is, as an azimuth in this instance's own local frame — the anchor the
// motes' arc is centred on, so they never orbit round the far side. it has to be computed per
// instance and cannot be a uniform, and the reason is the TRANSLATION rather than the rotation: two
// props of a kind stand in different cells, so the direction from each to the camera differs even
// when they are posed identically. (It was originally written for a stronger version of the same
// point — every glowing prop took PropYaw.HASHED then, so local +Z pointed somewhere different for
// each. They are all FRONTAL now; the per-instance frame is still required.) mat3 transpose is
// written out as two dots because
// three compiles its built-in materials as GLSL ES 1.00 even on WebGL2 (`transpose()` is 3.00 only),
// and the instance scale is uniform so it cancels inside the atan. BRACED: both this and
// render.world.PropShader's sway inject at <begin_vertex>, which is inside main(), so unbraced
// locals here would be a plain GLSL redefinition on any prop that took both
      var vert =
        '#include <begin_vertex>\n' +
        '  {\n' +
        '  vGlowPos = position;\n' +
        '  vGlowPh = 0.0;\n' +
        '  mat4 gm = modelMatrix;\n' +
        '  #ifdef USE_INSTANCING\n' +
        '    vGlowPh = fract( sin( instanceMatrix[ 3 ].x * 12.9898 +\n' +
        '      instanceMatrix[ 3 ].z * 78.233 ) * 43758.5453 );\n' +
        '    gm = modelMatrix * instanceMatrix;\n' +
        '  #endif\n' +
        '  vec3 gcd = cameraPosition - gm[ 3 ].xyz;\n' +
        // Z FIRST. the mote is placed at ( cos(ga), y, sin(ga) ), so the angle that points AT the
        // camera is atan2( localZ, localX ). atan2( x, z ) is the natural-looking spelling and it is
        // 90 degrees wrong — it put the whole sweep on the flank and the far side
        '  vGlowCam = atan( dot( gcd, gm[ 2 ].xyz ), dot( gcd, gm[ 0 ].xyz ) );\n' +
        '  }';
      // BRACED, and the loop bound is a LITERAL: the count rides the program cache key below, because
      // GLSL wants a constant bound and because a row that changes it must compile its own program
      // a RATIO and not a difference. diffuseColor here is LINEAR (three's sampler decoded the sRGB
      // map), where the albedo's absolute levels are tiny — a difference key would have to be retuned
      // for every prop, while a ratio is the same number in either space and does not move with how
      // dark the texel is. WHICH ratio is the row's, because it depends entirely on what the prop's
      // own art puts next to what: see PropKey in render.world.ObjModels for the measured modes
      var key = switch (s.key)
        {
          case GREEN: 'diffuseColor.g / max( max( diffuseColor.r, diffuseColor.b ), 1e-4 )';
          case AMBER: 'diffuseColor.g / max( diffuseColor.b, 1e-4 )';
        };
      var frag =
        '#include <emissivemap_fragment>\n' +
        '  {\n' +
        '  float glowKey = ' + key + ';\n' +
        '  float glowMask = smoothstep( propGlowKeyLo, propGlowKeyHi, glowKey );\n' +
        '  float glowSum = propGlowBase;\n' +
        '  for ( int i = 0; i < ' + s.motes + '; i ++ )\n' +
        '  {\n' +
        '    float gi = float( i );\n' +
        '    float g1 = propGlowHash( gi * 12.9898 + vGlowPh );\n' +
        '    float g2 = propGlowHash( gi * 78.233 + vGlowPh + 3.7 );\n' +
        '    float g3 = propGlowHash( gi * 37.719 + vGlowPh + 11.3 );\n' +
        // the climb, and a radius that tapers with it so the helix tracks a spire's own profile
        // instead of leaving the mote hanging in the air near the crown
        '    float gu = fract( propGlowTime * propGlowRise * ( 0.7 + 0.6 * g1 ) + g2 );\n' +
        // the sweep is anchored ON THE CAMERA and never completes a lap: a mote that orbits the far
        // side is invisible for half its cycle, and with every mote back there the prop goes dead
        // (measured at 8 motes: hotPx 26 / 6 / 0 across three captures). so the angle ping-pongs
        // across the near face through +/- propGlowFront instead. the sine costs the lap — a mote
        // now eases, reverses at the silhouette and comes back — and that is the trade for never
        // losing one. propGlowFront = PI degrades back to a full sweep, so the option is not gone.
        // a 2*PI jump when the camera crosses the instance's local -Z is invisible: ga only ever
        // reaches the world through cos/sin
        '    float gsw = propGlowTime * propGlowSpin * ( 0.7 + 0.6 * g3 ) + g2 * 6.2832;\n' +
        '    float ga = vGlowCam + propGlowFront * sin( gsw );\n' +
        '    float gr = propGlowSpan * propGlowR * mix( 1.0, propGlowRTop, gu );\n' +
        // the climb runs yLo..1 of the span rather than the whole of it, for a prop whose glowing
        // part does not reach the floor — the mask would reject the bottom of the lap anyway, and on
        // a low mote count that is a real share of the budget spent lighting nothing
        '    vec3 gp = propGlowCentre + vec3( cos( ga ) * gr,\n' +
        '      propGlowSpan * mix( propGlowYLo, 1.0, gu ), sin( ga ) * gr );\n' +
        // a bell over the climb: gu wraps at 1, and without this the mote would blink out at the
        // crown and back in at the foot every lap. SQRT of the sine, not the sine: a plain bell has
        // a mote under half brightness for half its climb, so with 8 of them several are always
        // washed out and the prop reads near-empty. sqrt still reaches 0 at both ends — a floor
        // would pop at the wrap — but it gets to full in a fifth of the climb and stays there.
        // the max() is not defensive: sin can return a hair below 0 at the ends, sqrt of that is
        // NaN, and ONE NaN texel goes through the bloom downsample and blacks out the whole frame
        '    float gw = sqrt( max( 0.0, sin( gu * 3.14159 ) ) );\n' +
        // a TIGHT shoulder, and it matters more than moteR does. at 4.0 the tail is still 2% of a
        // peak that is well over the bloom threshold, so the dot read as a soft patch of lit crystal
        // rather than as a mote sitting on it
        '    float gd = distance( vGlowPos, gp ) / ( propGlowSpan * propGlowMoteR );\n' +
        '    glowSum += propGlowMote * gw * exp( - gd * gd * 6.0 );\n' +
        '  }\n' +
        '  totalEmissiveRadiance += propGlowColor * glowMask * glowSum;\n' +
        '  }';
      // Dynamic, and it cannot be a typed function: `prev` is CALLED like one below and also carries
      // the previous patch's marker FIELDS, which the loop further down copies with Reflect. Haxe has
      // no type for "function with arbitrary own properties", which is exactly what a JS hook is here
      var prev:Dynamic = mat.onBeforeCompile;
      // an OWN key only. three's Material carries a DEFAULT customProgramCacheKey on the PROTOTYPE
      // returning this.onBeforeCompile.toString(), so the field is never null and taking it blindly
      // yields a function that throws unbound on every draw and blanks the frame — the trap
      // render.sewer.SewerMask.patch documents, measured at 838 errors and 0 draw calls
      var prevKey:Dynamic = untyped mat.hasOwnProperty('customProgramCacheKey') ?
        mat.customProgramCacheKey : null;
      // same reason as `prev`: this function is handed marker fields below, so it is a JS function
      // object rather than a Haxe function value
      var hook:Dynamic = function(shader:ShaderPatch, renderer:Dynamic)
        {
          if (prev != null)
            prev(shader, renderer);
          shader.uniforms.propGlowTime = uTime;
          shader.uniforms.propGlowCentre = u.centre;
          shader.uniforms.propGlowSpan = u.span;
          shader.uniforms.propGlowColor = u.color;
          shader.uniforms.propGlowKeyLo = u.keyLo;
          shader.uniforms.propGlowKeyHi = u.keyHi;
          shader.uniforms.propGlowBase = u.base;
          shader.uniforms.propGlowMote = u.mote;
          shader.uniforms.propGlowMoteR = u.moteR;
          shader.uniforms.propGlowR = u.r;
          shader.uniforms.propGlowRTop = u.rTop;
          shader.uniforms.propGlowYLo = u.yLo;
          shader.uniforms.propGlowRise = u.rise;
          shader.uniforms.propGlowSpin = u.spin;
          shader.uniforms.propGlowFront = u.front;
          shader.vertexShader = 'varying vec3 vGlowPos;\n' +
            'varying float vGlowPh;\n' +
            'varying float vGlowCam;\n' +
            StringTools.replace(shader.vertexShader, '#include <begin_vertex>', vert);
          // <emissivemap_fragment> is the anchor because it is where three has just finished with
          // totalEmissiveRadiance and diffuseColor is still in scope — one anchor gives both the
          // additive slot and the albedo the mask is keyed on. the prop carries no emissive map and
          // its `emissive` is black, so this term is the only contributor
          shader.fragmentShader = decl +
            StringTools.replace(shader.fragmentShader, '#include <emissivemap_fragment>', frag);
        };
      // carry forward the marks of whatever hook we just wrapped. BOTH tests above read the
      // OUTERMOST hook, so a marker that got chained over reads as absent and its owner re-patches —
      // and since it then wraps US, our own mark disappears too and we re-patch on the next frame.
      // that is a mutual loop, one round per frame, and every round is a NEW program: measured live
      // between the mask and the sway at a 21-deep key and 95 -> 129 programs in four seconds
      if (prev != null)
        for (f in Reflect.fields(prev))
          Reflect.setField(hook, f, Reflect.field(prev, f));
      hook.propGlow = true;
      mat.onBeforeCompile = hook;
      // three keys its program cache on base material params, NOT on onBeforeCompile — without a key
      // of our own a glowing program could be handed to an identical unlit-of-this prop. CHAINED,
      // because these materials already carry SewerMask's hook and its key. the mote count and the
      // mask key are both in it because both are LITERALS in the source above, not uniforms
      mat.customProgramCacheKey = function()
        return (prevKey != null ? Std.string(Reflect.callMethod(mat, prevKey, [])) : '') +
          'propGlow' + s.motes + s.key;
      mat.needsUpdate = true;
    }
}
