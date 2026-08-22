package render.world;

import three.Three;
import render.RenderConfig;
import render.world.ObjModels.PropShine;
import render.world.ObjModels.PropKey;
import render.world.ObjModels.PropEyes;
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
// preservator's are 3 huge blobs on a deliberately soft one, which reads as light inside a shell
// rather than as anything sitting on it.
//
// a third term rides on top of both: a slow BREATH over the whole glow (`pulse` / `pulseRate`). its
// value is not the wobble, it is WHERE the wobble sits — the preservator's is fitted so a mote peak
// clears BLOOM_THRESHOLD at the top of the cycle and misses it at the bottom, so the halo itself
// appears and goes. A brightness change that never crosses the threshold is only a shade, which is
// what the preservator's first pass shipped as and why nobody could find it.
//
// a THIRD term was tried and removed: object space quantised into cells, each swelling on a beat of
// its own, as a low shimmer so the crystal was not dead between motes. It read as flat rectangular
// patches — a cube lattice has no relation to where the mesh's own facets actually are, and at any
// amplitude that showed at all, the lattice showed with it.
//
// a SECOND, independent effect rides in this same patch: the `eyes` column. It does not glow — it
// REPAINTS diffuseColor inside a table of measured discs, replacing whatever eyes the generator baked
// with a sclera, an iris and a pupil that drift. It lives here rather than in a module of its own
// because everything it needs already exists in this one — the local-position varying, the bounding
// box frame, the clock and the per-instance phase — and because a fourth copy of the hook-chaining
// boilerplate below (there are already three: SewerMask, PropShader and this) would add another link
// to a cache key that is walked on every material.
//
// like render.world.PropShader it costs NO draw call, NO pass and NO geometry: the props stay the same
// instanced batches drawing the same materials, and everything here is arithmetic in a fragment shader
// that was already running. the halo is the composer's existing bloom pass catching an HDR tint — the
// recipe every glowing thing in this game uses.
//
// WHICH props glow is the `shine` column of render.world.ObjModels.MODELS and which have eyes is its
// `eyes` column. The two are independent, either may be null, and a row with both null is simply
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
  public static function patchMesh(o:Object3D, s:PropShine, e:PropEyes):Void
    {
      if ((s == null && e == null) ||
          !RenderConfig.PROP_GLOW.enabled)
        return;
      if (o != null &&
          o.material != null &&
          o.geometry != null)
        patch(o.material, o.geometry, s, e);
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
  public static function patch(mat:Dynamic, geo:BufferGeometry, s:PropShine, e:PropEyes):Void
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
      var hasS = (s != null);
      var hasE = (e != null);
      // the eye tables, resolved to LOCAL units once here rather than per fragment. `eyeC` is centre +
      // radius, `eyeF` the unit direction the eye faces (which is what the near-hemisphere clip and
      // the gaze's tangent projection both need) and `eyeG` the highlight's offset from the centre.
      // all three are constant per prop, so a shader that recomputed them would pay a normalize per
      // eye per fragment for a number that never changes
      var eyeC = [];
      var eyeF = [];
      var eyeG = [];
      if (hasE)
        {
          // the fixed direction the wet highlight sits toward, in local space: up and to the camera's
          // left, where a tunnel's wall fixtures hang. one room has one light, so every eye on the
          // prop catches it in the same place — which is exactly what makes a set of eyes read as wet
          // rather than as a set of stickers
          var gx = -0.5, gy = 1.0, gz = 0.0;
          for (row in e.list)
            {
              var cxw = centre.x + row.x * span;
              var cyw = centre.y + row.y * span;
              var czw = centre.z + row.z * span;
              eyeC.push(new Vector4(cxw, cyw, czw, row.r * span));
              var fx = cxw - (centre.x + e.ax * span);
              var fy = cyw - (centre.y + e.ay * span);
              var fz = czw - (centre.z + e.az * span);
              var fl = Math.sqrt(fx * fx + fy * fy + fz * fz);
              // an eye sitting exactly on the anchor has no outward direction, and normalizing a zero
              // vector is NaN — one NaN texel goes through the bloom downsample and blacks out the
              // WHOLE frame. it cannot happen with the anchor authored behind the body (see PropEyes),
              // and this is here so that a mis-authored row is a wrong-facing eye and not a dead frame
              if (fl < 1e-5)
                {
                  fx = 0;
                  fy = 0;
                  fz = 1;
                  fl = 1;
                }
              eyeF.push(new Vector3(fx / fl, fy / fl, fz / fl));
              // the highlight direction projected onto THIS eye's tangent plane, then scaled to the
              // authored offset. same Gram-Schmidt the gaze uses, and it degrades to a centred glint
              // if the light happens to lie along the eye's own axis
              var d = (gx * fx + gy * fy + gz * fz) / fl;
              var px = gx - fx / fl * d;
              var py = gy - fy / fl * d;
              var pz = gz - fz / fl * d;
              var pl = Math.sqrt(px * px + py * py + pz * pz);
              var k = pl < 1e-5 ? 0.0 : e.glintOff * row.r * span / pl;
              eyeG.push(new Vector3(px * k, py * k, pz * k));
            }
        }
      var u = {
        centre: { value: centre },
        span: { value: span },
        // HDR: past 1 is what carries the mote peaks over the bloom threshold, the recipe
        // render.TacticalGrid and render.PathLine use. green is the CHEAPEST channel to bloom with —
        // linear luminance weighs it 0.7152 against blue's 0.0722, the trap the cool wall fixtures hit
        color: { value: hasS ? new Color(s.color).multiplyScalar(s.glow) : new Color(0) },
        keyLo: { value: hasS ? s.keyLo : 0.0 },
        keyHi: { value: hasS ? s.keyHi : 1.0 },
        base: { value: hasS ? s.base : 0.0 },
        mote: { value: hasS ? s.mote : 0.0 },
        moteR: { value: hasS ? s.moteR : 1.0 },
        r: { value: hasS ? s.r : 0.0 },
        rTop: { value: hasS ? s.rTop : 1.0 },
        yLo: { value: hasS ? s.yLo : 0.0 },
        rise: { value: hasS ? s.rise : 0.0 },
        spin: { value: hasS ? s.spin : 0.0 },
        front: { value: hasS ? s.front : 0.0 },
        pulse: { value: hasS ? s.pulse : 0.0 },
        pulseRate: { value: hasS ? s.pulseRate : 0.0 },
        eyeC: { value: eyeC },
        eyeF: { value: eyeF },
        eyeG: { value: eyeG },
        eyeIris: { value: hasE ? e.iris : 0.0 },
        eyePupil: { value: hasE ? e.pupil : 0.0 },
        eyeGaze: { value: hasE ? e.gaze : 0.0 },
        eyeGazeRate: { value: hasE ? e.gazeRate : 0.0 },
        // clamped away from 0 because it is a smoothstep WIDTH: a zero-width one is a divide by zero
        // and every fragment of the prop comes back NaN
        eyeSnap: { value: hasE ? Math.max(e.gazeSnap, 1e-3) : 1.0 },
        eyeSclera: { value: hasE ? new Color(e.sclera) : new Color(0) },
        eyeIrisCol: { value: hasE ? new Color(e.irisColor) : new Color(0) },
        eyePupilCol: { value: hasE ? new Color(e.pupilColor) : new Color(0) },
        eyeLid: { value: hasE ? new Color(e.lid) : new Color(0) },
        eyeBlinkRate: { value: hasE ? e.blinkRate : 0.0 },
        // clamped away from 0 because it is a smoothstep WIDTH below, and a zero-width one is a
        // divide by zero rather than a hard edge
        eyeBlinkDuty: { value: hasE ? Math.max(e.blinkDuty, 1e-3) : 1.0 },
        eyeGlint: { value: hasE ? e.glint : 0.0 },
        eyeGlintR: { value: hasE ? e.glintR : 1.0 },
      };
      var decl =
        'uniform float propGlowTime;\n' +
        'uniform vec3 propGlowCentre;\n' +
        'uniform float propGlowSpan;\n' +
        (hasS ?
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
          'uniform float propGlowPulse;\n' +
          'uniform float propGlowPulseRate;\n' : '') +
        (hasE ?
          // the eye table. sized by a LITERAL because GLSL wants a constant array bound, which is why
          // the count is in the program cache key below
          'uniform vec4 propEyeC[ ' + e.list.length + ' ];\n' +
          'uniform vec3 propEyeF[ ' + e.list.length + ' ];\n' +
          'uniform vec3 propEyeG[ ' + e.list.length + ' ];\n' +
          'uniform float propEyeIris;\n' +
          'uniform float propEyePupil;\n' +
          'uniform float propEyeGaze;\n' +
          'uniform float propEyeGazeRate;\n' +
          'uniform float propEyeSnap;\n' +
          'uniform vec3 propEyeSclera;\n' +
          'uniform vec3 propEyeIrisCol;\n' +
          'uniform vec3 propEyePupilCol;\n' +
          'uniform vec3 propEyeLid;\n' +
          'uniform float propEyeBlinkRate;\n' +
          'uniform float propEyeBlinkDuty;\n' +
          'uniform float propEyeGlint;\n' +
          'uniform float propEyeGlintR;\n' : '') +
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
        '}\n' +
        (hasE ?
          // where eye `e` is looking during fixation `n` — a direction, not yet projected onto that
          // eye's own tangent plane. components are -1..1 rather than a unit vector on purpose: the
          // MAGNITUDE varies too, so an eye sometimes settles near centre and sometimes hard to one
          // side, which is what stops eight of them reading as a mechanism
          'vec3 propEyeDir( float n, float e )\n' +
          '{\n' +
          '  return vec3( propGlowHash( n * 1.7 + e * 13.1 ) * 2.0 - 1.0,\n' +
          '               propGlowHash( n * 3.3 + e * 7.7 + 5.1 ) * 2.0 - 1.0,\n' +
          '               propGlowHash( n * 5.9 + e * 3.3 + 11.7 ) * 2.0 - 1.0 );\n' +
          '}\n' : '');
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
      var key = !hasS ? '' : switch (s.key)
        {
          case GREEN: 'diffuseColor.g / max( max( diffuseColor.r, diffuseColor.b ), 1e-4 )';
          case AMBER: 'diffuseColor.g / max( diffuseColor.b, 1e-4 )';
        };
      var shine = !hasS ? '' :
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
        // the whole glow's own beat, base and motes TOGETHER — so the level crosses the bloom
        // threshold rather than wobbling on one side of it, which is the only version of this a
        // player can actually see. per-instance phase off vGlowPh, so two pods in one room never
        // breathe in step. at pulse 0 the whole expression is exactly 1.0 and nothing changes, which
        // is what lets a row opt out without a second program
        '  glowSum *= 1.0 - propGlowPulse + propGlowPulse *\n' +
        '    ( 0.5 + 0.5 * sin( propGlowTime * propGlowPulseRate + vGlowPh * 6.2832 ) );\n' +
        '  totalEmissiveRadiance += propGlowColor * glowMask * glowSum;\n' +
        '  }';
      // THE EYES. it writes diffuseColor rather than adding emissive, because it REPLACES the baked
      // eye instead of lighting it: a baked pupil cannot be shifted in uv space and a second one drawn
      // over it is simply two. <emissivemap_fragment> is the right anchor for that too — it runs
      // BEFORE <lights_physical_fragment> builds the material from diffuseColor, so a repainted eye is
      // lit and shadowed like the flesh around it rather than pasted flat over the shading.
      //
      // BRACED, and the loop bound is a LITERAL for the reason the mote loop's is. every per-eye
      // constant that could be hoisted has been (see eyeC/eyeF/eyeG above), so the per-fragment cost
      // is one length, one dot and a handful of smoothsteps per eye
      var eyes = !hasE ? '' :
        '  {\n' +
        '  vec3 eyeCol = vec3( 0.0 );\n' +
        '  float eyeM = 0.0;\n' +
        '  float eyeGl = 0.0;\n' +
        '  for ( int i = 0; i < ' + e.list.length + '; i ++ )\n' +
        '  {\n' +
        '    vec4 ec = propEyeC[ i ];\n' +
        '    vec3 ef = propEyeF[ i ];\n' +
        '    vec3 dv = vGlowPos - ec.xyz;\n' +
        // split into the eye's OWN frame: how far along its axis, and how far across its face. the
        // radial part is the honest "where on this eye am I" — a raw 3D distance mixes the two, and
        // on a curved cap that overstates the radius toward the rim
        '    float ax = dot( dv, ef );\n' +
        '    vec3 rv = dv - ef * ax;\n' +
        // a CYLINDER along the axis, not a sphere-plus-hemisphere. the hemisphere version rejected
        // 48-76% of every disc, measured, rising monotonically with radius: the centre sits at the
        // cap's apex, so the whole eye lies at NEGATIVE ax, and `step( 0.0, dot )` cut the rim off
        // every one of them. That is what left a ring of the baked eye showing outside the repaint.
        //
        // the slab is offset back and deliberately tight in FRONT: the cap spans only ~0.16 of its own
        // radius in depth, the far side of the body is 4-11 radii behind, and the only thing that can
        // sit just in front is a tendril arcing over the eye — which must not be painted white
        '    float on = ( 1.0 - smoothstep( ec.w * 0.88, ec.w, length( rv ) ) ) *\n' +
        '      ( 1.0 - smoothstep( ec.w * 0.55, ec.w * 0.95, abs( ax + ec.w * 0.3 ) ) );\n' +
        '    float fi = float( i );\n' +
        '    float h1 = propGlowHash( fi * 12.9898 + 0.7 );\n' +
        '    float h2 = propGlowHash( fi * 78.233 + 3.7 );\n' +
        // THE GAZE, and it is a SACCADE rather than a drift. an eye holds one fixation for most of a
        // cycle and then flicks to the next in a fraction of it, which is what a real one does and
        // what a sum of sines cannot express — that first version swept smoothly and read as floating.
        //
        // no state: the fixation INDEX is floor of the clock and its two endpoints are hashed off that
        // index, so the whole thing is a closed form. `gk + 1` is the next fixation's target, which is
        // the same value the next cycle reads as its own start, so the sequence is continuous with no
        // pop at the handover. the index wraps at 64 to keep the hash's input small — it amplifies
        // input error by 43758 — which costs a repeat every 64 fixations, unobservable when each eye
        // runs at a rate of its own
        '    float gr = propEyeGazeRate * ( 0.7 + 0.6 * h1 );\n' +
        '    float gp = propGlowTime * gr + h2 + vGlowPh;\n' +
        '    float gk = mod( floor( gp ), 64.0 );\n' +
        '    vec3 gi = mix( propEyeDir( gk, fi ), propEyeDir( mod( gk + 1.0, 64.0 ), fi ),\n' +
        '      smoothstep( 1.0 - propEyeSnap, 1.0, fract( gp ) ) );\n' +
        // squashed vertically, because eyes scan SIDE TO SIDE far more than up and down. this is in
        // world axes rather than the eye's own, which is exactly right here and only here: every
        // grown organ is PropYaw.FRONTAL, so world Y is up on the prop and every eye's tangent plane
        // contains it. it would be wrong on a prop that could be turned
        '    gi.y *= 0.55;\n' +
        // Gram-Schmidt onto THIS eye's tangent plane, which is what turns one noise vector into a
        // per-eye gaze — and it has no degenerate case, unlike a cross-product basis, which matters
        // because several of these eyes sit where the outward direction is almost straight up.
        //
        // then CLAMPED to unit length rather than divided by 1/sqrt(3), which is what it first
        // shipped as and why the pupils read as stationary. sqrt(3) is the bound on a vec3 of sines,
        // so dividing by it is correct and useless: the tangential part of that vector has a typical
        // length near 0.8, so the typical throw was 46% of an already small ceiling — under a pixel
        // on a 13px eye. clamping instead spends the whole authored range on the common case and only
        // trims the rare overshoot, and the magnitude still varies underneath, which is what keeps a
        // pupil sometimes centred and sometimes against the rim instead of endlessly circling
        '    vec3 off = gi - ef * dot( gi, ef );\n' +
        '    off *= propEyeGaze * ec.w * min( 1.0, 1.0 / max( length( off ), 1e-4 ) );\n' +
        // `rv` and not `dv`: both are already in the eye's tangent plane, so the iris is a true circle
        // ON the eye's face rather than the intersection of a sphere with a curved surface
        '    float di = length( rv - off );\n' +
        '    float ri = ec.w * propEyeIris;\n' +
        '    float rp = ri * propEyePupil;\n' +
        '    float iris = 1.0 - smoothstep( ri * 0.8, ri, di );\n' +
        '    float pup = 1.0 - smoothstep( rp * 0.7, rp, di );\n' +
        // the wet highlight, at a FIXED offset in the eye's own frame — a reflection is where the
        // light is, and one that travelled with the pupil would read as a decal
        '    float gw = ec.w * propEyeGlintR;\n' +
        '    float gl = 1.0 - smoothstep( gw * 0.55, gw, length( rv - propEyeG[ i ] ) );\n' +
        // the blink: shut for the first `duty` of this eye's own cycle and open for the rest, so the
        // ramps meet 0 at both ends of that window and nothing pops at the wrap
        '    float bt = fract( propGlowTime * propEyeBlinkRate + h1 + vGlowPh );\n' +
        '    float lid = smoothstep( 0.0, propEyeBlinkDuty * 0.3, bt ) *\n' +
        '      ( 1.0 - smoothstep( propEyeBlinkDuty * 0.7, propEyeBlinkDuty, bt ) );\n' +
        '    vec3 c = mix( mix( propEyeSclera, propEyeIrisCol, iris ), propEyePupilCol, pup );\n' +
        '    eyeCol += mix( c, propEyeLid, lid ) * on;\n' +
        '    eyeM += on;\n' +
        '    eyeGl += gl * on * ( 1.0 - lid );\n' +
        '  }\n' +
        // accumulated and then normalized rather than composited in the loop: the discs do not overlap
        // on any authored table, and if one ever did this averages the two instead of letting whichever
        // eye came last in the array win
        '  eyeM = min( eyeM, 1.0 );\n' +
        '  diffuseColor.rgb = mix( diffuseColor.rgb, eyeCol / max( eyeM, 1e-4 ), eyeM );\n' +
        // and the only part of an eye that is emissive. HDR, so the bloom pass gives a ~15px disc a
        // halo bigger than itself — which at this camera is most of what makes an eye read at all
        '  totalEmissiveRadiance += propEyeSclera * ( propEyeGlint * min( eyeGl, 1.0 ) );\n' +
        '  }';
      var frag = '#include <emissivemap_fragment>\n' + shine + eyes;
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
          if (hasS)
            {
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
              shader.uniforms.propGlowPulse = u.pulse;
              shader.uniforms.propGlowPulseRate = u.pulseRate;
            }
          if (hasE)
            {
              shader.uniforms.propEyeC = u.eyeC;
              shader.uniforms.propEyeF = u.eyeF;
              shader.uniforms.propEyeG = u.eyeG;
              shader.uniforms.propEyeIris = u.eyeIris;
              shader.uniforms.propEyePupil = u.eyePupil;
              shader.uniforms.propEyeGaze = u.eyeGaze;
              shader.uniforms.propEyeGazeRate = u.eyeGazeRate;
              shader.uniforms.propEyeSnap = u.eyeSnap;
              shader.uniforms.propEyeSclera = u.eyeSclera;
              shader.uniforms.propEyeIrisCol = u.eyeIrisCol;
              shader.uniforms.propEyePupilCol = u.eyePupilCol;
              shader.uniforms.propEyeLid = u.eyeLid;
              shader.uniforms.propEyeBlinkRate = u.eyeBlinkRate;
              shader.uniforms.propEyeBlinkDuty = u.eyeBlinkDuty;
              shader.uniforms.propEyeGlint = u.eyeGlint;
              shader.uniforms.propEyeGlintR = u.eyeGlintR;
            }
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
      // because these materials already carry SewerMask's hook and its key. the mote count, the mask
      // key and the EYE COUNT are all in it because all three are LITERALS in the source above, not
      // uniforms — and the converse is why `pulse`, the whole eye table and every rate deliberately
      // are: a row can retune any of them, or turn a half off entirely, without adding a permutation
      // to compile and to warm. WHICH HALVES are present is in the key for the same reason it is in
      // render.world.PropShader's: they are emitted conditionally, so a shine-only and an eyes-only
      // prop are two different sources. a shine-only row's key is byte-identical to what it was
      // before the eyes existed, so nothing already warmed re-compiles
      mat.customProgramCacheKey = function()
        return (prevKey != null ? Std.string(Reflect.callMethod(mat, prevKey, [])) : '') +
          'propGlow' + (hasS ? Std.string(s.motes) + s.key : '') +
          (hasE ? 'E' + e.list.length : '');
      mat.needsUpdate = true;
    }
}
