package render.world;

import three.Three;
import render.RenderConfig;
import render.world.ObjModels.PropAnim;
import render.world.ObjModels.PropPulse;
import render.world.ObjModels.PropCurl;

// the object three hands an onBeforeCompile hook: the shader sources about to be compiled, plus the
// uniform bag to register ours in. `uniforms` stays Dynamic and cannot be anything else — it is an
// OPEN MAP whose keys are whatever the material's own chunks declared plus whatever every patch in
// the chain adds, so there is no closed set of fields to name. The sources are plain strings
typedef ShaderPatch = {
  uniforms:Dynamic,     // name -> { value: ... }, open by construction (see above)
  vertexShader:String,  // full source, pre-compile; patched by string replacement at chunk anchors
  fragmentShader:String,
};

// the grown props' IDLE MOTION, folded into the materials they already draw with. four terms, all
// pure vertex shader, all driven by one shared clock. two of them are the `anim` column:
//   SWAY   — a height-weighted lateral offset on the geometry itself, so an organ's limbs drift and
//            its feet stay planted. this is the part that reads without any light at all, because it
//            moves the SILHOUETTE.
//   SHEEN  — a faster ripple applied to the shading normal ALONE, no displacement. this is the part a
//            specular highlight crawls on. it needs an analytic light to show: underground that is
//            the pooled lamp spots, plus a much weaker contribution through the hemisphere light
//            (which keys on normal.y). an organ with no `light` of its own and no lamp bracket near
//            it has only the hemisphere term, so expect this half to be faint on one — see
//            docs/3d-changes.md
// and two are the `pulse` column, which is a different animal and exists for a different shape of
// prop. a sway weight is a POWER of normalized height: smooth, and never exactly zero anywhere. that
// is right for an arch of drifting limbs and wrong for a pod welded to the floor by a root pool, so:
//   SWELL  — a radial SCALE about the prop's own vertical axis, gated to nothing at all below an
//            authored floor line and ramped in above it. a scale rather than an offset, so the
//            displacement is proportional to how far out a vertex already is, which is both what an
//            inflating body does and what keeps the field continuous under any weight.
//   TWIST  — a rotation about the same axis under the same gate. on a body of revolution this is the
//            term that reads as writhing: a lateral sway only leans such a shape, while a turn slides
//            its whole surface — and its whole painted detail — around itself.
// and one is the `curl` column, which is a THIRD shape again:
//   CURL   — a tangential sweep about the prop's own DEPTH axis, gated by height AND by distance from
//            that axis, with the phase travelling round the fan. this is the shape for limbs
//            radiating from a core, which neither of the two above can express — a sway weighted by
//            height cannot move a limb sticking straight out sideways without dragging the core with
//            it, and a turn about the VERTICAL moves a limb on a shallow fan almost entirely in
//            depth. see the PropCurl header in render.world.ObjModels for the measurements.
//
// it deliberately costs NO draw call, NO pass and NO geometry, the same trade render.sewer.SewerMask
// makes: the props stay the same instanced batches drawing the same materials, and everything here is
// arithmetic in a vertex shader that was already running.
//
// WHICH props move is not decided here — it is the `anim`, `pulse` and `curl` columns of
// render.world.ObjModels.MODELS. the three are independent, any may be null, and a row with all
// three null is simply never patched (so it also keeps the shared unpatched program)
class PropShader
{
  // the clock every patched material references BY IDENTITY, in BASE_MS units — so per-prop `rate`
  // values are plain multipliers and writing .value here reaches every material at once, exactly the
  // uniform-sharing SewerMask uses for the mask texture
  static var uTime = { value: 0.0 };

// advance the shared clock. call once per frame from the area kind's tick, BEFORE the patches below
// (a material patched this frame reads the value already written)
  public static function tick(dtMs:Float):Void
    {
      uTime.value += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
    }

// patch a mesh's material, tolerating a mesh that is not there yet and a prop that does not animate.
// every glb-backed prop arrives through a loader callback, so its InstancedMesh is null for the first
// frames — the same reason SewerMask.patchMesh exists and is called per frame rather than at build
  public static function patchMesh(o:Object3D, a:PropAnim, p:PropPulse, c:PropCurl):Void
    {
      if ((a == null && p == null && c == null) ||
          !RenderConfig.PROP_ANIM.enabled)
        return;
      if (o != null &&
          o.material != null &&
          o.geometry != null)
        patch(o.material, o.geometry, a, p, c);
    }

// fold the motion into one material. `geo` is needed as well as the material because the weights are
// normalized over the prop's OWN vertical extent: render.Models.normalize recenters a template by
// moving root.position and render.Models.instanced folds that offset into the instance matrix
// analytically, so raw position.y is NOT zero-based and no constant can stand in for it.
//
// everything authored per prop is a FRACTION of that extent rather than a world number, for the
// reason SewerProp.margin was replaced by `r`: Models.instanced scales by HEIGHT alone, so any
// hand-typed world constant silently stops meaning what it said the moment a row's `h` is edited
// `mat` is Dynamic at a real boundary and not for convenience: three's materials have no base
// extern here (Standard, Basic and Lambert are three unrelated classes in three.Three), and none of
// them declares onBeforeCompile / customProgramCacheKey / needsUpdate — this patches all three kinds
// through one path. Typing it would take a Material supertype in the extern, which is its own change
  public static function patch(mat:Dynamic, geo:BufferGeometry, a:PropAnim, p:PropPulse, c:PropCurl):Void
    {
      // the mark lives on the HOOK and not in userData: Material.clone() copies userData but NOT
      // onBeforeCompile, so a userData flag would ride onto the GHOST clones render.Models makes from
      // a patched template and lock them out of the patch they never received (SewerMask.hx carries
      // the obituary — it was found live, on the exit ladder's ghost)
      if (mat.onBeforeCompile != null &&
          mat.onBeforeCompile.propAnim == true)
        return;
      if (geo.boundingBox == null)
        geo.computeBoundingBox();
      var bb = geo.boundingBox;
      var base = bb.min.y;
      var span = bb.max.y - base;
      if (span <= 0)
        return;
      // a material that does not shade takes the DISPLACEMENT ONLY. that is not an optimisation: the
      // tactical outline hull is a MeshBasicMaterial and has no lighting to tilt a normal for, but it
      // must still move, or the outline detaches from the body it exists to trace
      var lit = (mat.isMeshStandardMaterial == true);
      var hasA = (a != null);
      var hasP = (p != null);
      var hasC = (c != null);
      var u = {
        base: { value: base },
        span: { value: span },
        // authored as a fraction of the prop's height, converted to the local units `transformed`
        // lives in — so the same row reads the same at any `h`
        amp: { value: hasA ? a.amp * span : 0.0 },
        bend: { value: hasA ? a.bend : 1.0 },
        rate: { value: hasA ? a.rate : 0.0 },
        // phase cycles per prop-height across the local XZ plane, so separate limbs lead and lag
        // instead of the whole body swinging as one slab. 0 collapses it back to a whole-body flex
        strand: { value: hasA ? a.strand / span : 0.0 },
        sheen: { value: hasA ? a.sheen : 0.0 },
        sheenRate: { value: hasA ? a.sheenRate : 0.0 },
        // the axis the swell and the twist turn about. read off the box and not assumed to be the
        // origin for the reason `base` is: Models.normalize recenters a template by moving
        // root.position, so raw local coordinates are centred on nothing
        centre: { value: new Vector2((bb.min.x + bb.max.x) * 0.5, (bb.min.z + bb.max.z) * 0.5) },
        pAmp: { value: hasP ? p.amp : 0.0 },
        pRate: { value: hasP ? p.rate : 0.0 },
        pLift: { value: hasP ? p.lift : 0.0 },
        pFloor: { value: hasP ? p.floor : 0.0 },
        // clamped away from 0 because it is the WIDTH of a smoothstep and a zero-width one is a
        // divide by zero, not a hard edge — every fragment of the prop would come back NaN
        pSoft: { value: hasP ? Math.max(p.soft, 1e-3) : 1.0 },
        pTwist: { value: hasP ? p.twist : 0.0 },
        pTwistRate: { value: hasP ? p.twistRate : 0.0 },
        // the DEPTH axis the curl turns about: the prop's XY centre line, with the height authored as
        // a fraction and converted here. read off the box for the reason `base` is — Models.normalize
        // recenters a template by moving root.position, so raw local coordinates are centred on nothing
        cAxis: { value: new Vector2((bb.min.x + bb.max.x) * 0.5, hasC ? base + c.axis * span : base) },
        cAmp: { value: hasC ? c.curl : 0.0 },
        cRate: { value: hasC ? c.rate : 0.0 },
        cLobes: { value: hasC ? c.lobes * 1.0 : 0.0 },
        // authored in CYCLES, converted to radians here — so the row says "half a wave along a limb"
        // rather than carrying a 2*PI nobody can read
        cWave: { value: hasC ? c.wave * 6.2832 : 0.0 },
        cYFloor: { value: hasC ? c.yFloor : 0.0 },
        // clamped away from 0 for the reason pSoft is: a zero-width smoothstep is a divide by zero,
        // not a hard edge, and every fragment of the prop comes back NaN
        cYSoft: { value: hasC ? Math.max(c.ySoft, 1e-3) : 1.0 },
        cDFloor: { value: hasC ? c.dFloor : 0.0 },
        cDSoft: { value: hasC ? Math.max(c.dSoft, 1e-3) : 1.0 },
      };
      // the per-instance phase, read off the instance TRANSLATION and never off gl_InstanceID:
      // render.Models.cull repacks the surviving instances into the front of the buffer every frame,
      // so a given prop's index changes as the camera moves and an index-keyed phase would jitter.
      // the translation column is stable, costs no extra attribute, and makes two organs of the same
      // kind in one level move out of phase by construction
      var iphase =
        '  float propIPh = 0.0;\n' +
        '  #ifdef USE_INSTANCING\n' +
        '    propIPh = instanceMatrix[ 3 ].x * 0.37 + instanceMatrix[ 3 ].z * 0.29;\n' +
        '  #endif\n';
      // the sway takes a SECOND phase term on top of it, varying across the body. the pulse below
      // deliberately does not: a breath whose phase varies per vertex is not a breath, it is a shear
      var phase = iphase +
        '  float propPh = propIPh + ( position.x + position.z ) * propStrand;\n';
      // the two axes run at 0.83 of each other so they beat instead of tracing a straight line back
      // and forth, and the second carries a phase offset of its own so they never start together
      var wave =
        '  vec2 propWave = vec2( sin( propTime * propRate + propPh ),\n' +
        '                        sin( propTime * propRate * 0.83 + propPh * 1.7 + 1.3 ) );\n';
      // only what the row actually asked for is declared. a null half is not merely idle — its
      // uniforms would still be set every frame and its program key would still collide with a prop
      // that really does use them
      var decl =
        'uniform float propTime;\n' +
        'uniform float propBase;\n' +
        'uniform float propSpan;\n' +
        (hasA ?
          'uniform float propAmp;\n' +
          'uniform float propBend;\n' +
          'uniform float propRate;\n' +
          'uniform float propStrand;\n' +
          'uniform float propSheen;\n' +
          'uniform float propSheenRate;\n' +
          // 0 at the base, 1 at the crown: what keeps a prop's feet on the floor while its top drifts
          'float propWeight( float y )\n' +
          '{\n' +
          '  return pow( clamp( ( y - propBase ) / propSpan, 0.0, 1.0 ), propBend );\n' +
          '}\n' : '') +
        (hasP ?
          'uniform vec2 propCentre;\n' +
          'uniform float propPulseAmp;\n' +
          'uniform float propPulseRate;\n' +
          'uniform float propPulseLift;\n' +
          'uniform float propPulseFloor;\n' +
          'uniform float propPulseSoft;\n' +
          'uniform float propPulseTwist;\n' +
          'uniform float propPulseTwistRate;\n' : '') +
        (hasC ?
          'uniform vec2 propCurlAxis;\n' +
          'uniform float propCurlAmp;\n' +
          'uniform float propCurlRate;\n' +
          'uniform float propCurlLobes;\n' +
          'uniform float propCurlWave;\n' +
          'uniform float propCurlYFloor;\n' +
          'uniform float propCurlYSoft;\n' +
          'uniform float propCurlDFloor;\n' +
          'uniform float propCurlDSoft;\n' : '');
      // the swell and the turn, gated to nothing below the floor line. BRACED and injected at the
      // same anchor as the sway, which is inside main(), so its locals must not escape into that
      // block's scope — and render.world.PropGlow injects a third block there on any prop that also
      // glows. it runs on `transformed` rather than `position`, so it composes with the sway instead
      // of replacing it
      var swell =
        '  {\n' +
        iphase +
        '  float propPw = smoothstep( propPulseFloor, propPulseFloor + propPulseSoft,\n' +
        '    ( position.y - propBase ) / propSpan );\n' +
        '  float propPs = propPulseAmp * propPw * sin( propTime * propPulseRate + propIPh );\n' +
        '  float propPa = propPulseTwist * propPw *\n' +
        '    sin( propTime * propPulseTwistRate + propIPh * 1.3 );\n' +
        '  float propPc = cos( propPa );\n' +
        '  float propPn = sin( propPa );\n' +
        '  vec2 propPd = transformed.xz - propCentre;\n' +
        '  transformed.xz = propCentre +\n' +
        '    vec2( propPd.x * propPc - propPd.y * propPn,\n' +
        '          propPd.x * propPn + propPd.y * propPc ) * ( 1.0 + propPs );\n' +
        // the crown rises with the swell, so the body inflates instead of only fattening. keyed off
        // position.y and not transformed.y, so the sway's own displacement does not feed back into it
        '  transformed.y += ( position.y - propBase ) * propPs * propPulseLift;\n' +
        '  }';
      // the tangential sweep, about the LOCAL Z. BRACED for the reason the block above is: this is
      // the third block injected at <begin_vertex>, which is inside main(), so its locals must not
      // escape into a scope shared with the sway, the swell and render.world.PropGlow's.
      //
      // both gates read `position` and the rotation is applied to `transformed`, so the curl composes
      // with whatever the two above already did instead of feeding back into its own weights.
      //
      // the shading normal is deliberately NOT rotated with it. the sway carries a d(offset)/dy tilt
      // because its amplitude is a lever arm the length of the whole prop; this turns a matte tendril
      // by at most 0.13 rad under a weak spot, where the first-order shading change is invisible and
      // a second copy of this block at <beginnormal_vertex> is not worth what it costs to keep in sync
      var curl =
        '  {\n' +
        iphase +
        '  float propCy = smoothstep( propCurlYFloor, propCurlYFloor + propCurlYSoft,\n' +
        '    ( position.y - propBase ) / propSpan );\n' +
        '  vec2 propCv = position.xy - propCurlAxis;\n' +
        '  float propCr = length( propCv ) / propSpan;\n' +
        '  float propCd = smoothstep( propCurlDFloor, propCurlDFloor + propCurlDSoft, propCr );\n' +
        // the phase travels round the fan, which is what turns a rigid pinwheel into a wave passing
        // through it. `propCurlLobes` is an INTEGER by contract (see PropCurl): the azimuth wraps at
        // +/-PI and only a whole number of cycles leaves this sin() continuous across that wrap.
        // the 1e-4 is a NaN guard and not a fudge — atan( 0, 0 ) is undefined, this block runs on
        // every vertex including the ones sitting ON the axis, and one NaN texel goes through the
        // bloom downsample and blacks out the WHOLE frame. it cannot be left to the gate zeroing the
        // angle, because NaN * 0 is still NaN
        // the radial term is what makes a limb UNDULATE instead of hinging: without it every vertex
        // of one limb leans by the same angle and the whole fan is a set of rigid spokes. it is
        // subtracted rather than added so the ripple travels outward, from the body toward the tips
        '  float propCa = propCurlAmp * propCy * propCd * sin( propTime * propCurlRate +\n' +
        '    atan( propCv.y, propCv.x + 1e-4 ) * propCurlLobes - propCr * propCurlWave + propIPh );\n' +
        '  float propCc = cos( propCa );\n' +
        '  float propCn = sin( propCa );\n' +
        '  vec2 propCt = transformed.xy - propCurlAxis;\n' +
        '  transformed.xy = propCurlAxis +\n' +
        '    vec2( propCt.x * propCc - propCt.y * propCn,\n' +
        '          propCt.x * propCn + propCt.y * propCc );\n' +
        '  }';
      // Dynamic, and it cannot be a typed function: `prev` is CALLED like one below and also carries
      // the previous patch's marker FIELDS, which the loop further down copies with Reflect. Haxe has
      // no type for "function with arbitrary own properties", which is exactly what a JS hook is here
      var prev:Dynamic = mat.onBeforeCompile;
      // an OWN key only. three's Material carries a DEFAULT customProgramCacheKey on the PROTOTYPE
      // returning this.onBeforeCompile.toString(), so the field is never null and taking it blindly
      // yields a function that throws unbound on every draw and blanks the frame — the trap
      // SewerMask.patch documents, measured at 838 errors and 0 draw calls
      // Dynamic because it is invoked through Reflect.callMethod with the material as the receiver —
      // a key function is a METHOD and may read `this`, which a typed function value cannot express
      var prevKey:Dynamic = untyped mat.hasOwnProperty('customProgramCacheKey') ?
        mat.customProgramCacheKey : null;
      // same reason as `prev`: this function is handed marker fields below, so it is a JS function
      // object rather than a Haxe function value. `renderer` is opaque here — forwarded to the hook
      // we wrapped and never read, so there is nothing to gain from naming its type
      var hook:Dynamic = function(shader:ShaderPatch, renderer:Dynamic)
        {
          if (prev != null)
            prev(shader, renderer);
          shader.uniforms.propTime = uTime;
          shader.uniforms.propBase = u.base;
          shader.uniforms.propSpan = u.span;
          if (hasA)
            {
              shader.uniforms.propAmp = u.amp;
              shader.uniforms.propBend = u.bend;
              shader.uniforms.propRate = u.rate;
              shader.uniforms.propStrand = u.strand;
              shader.uniforms.propSheen = u.sheen;
              shader.uniforms.propSheenRate = u.sheenRate;
            }
          if (hasP)
            {
              shader.uniforms.propCentre = u.centre;
              shader.uniforms.propPulseAmp = u.pAmp;
              shader.uniforms.propPulseRate = u.pRate;
              shader.uniforms.propPulseLift = u.pLift;
              shader.uniforms.propPulseFloor = u.pFloor;
              shader.uniforms.propPulseSoft = u.pSoft;
              shader.uniforms.propPulseTwist = u.pTwist;
              shader.uniforms.propPulseTwistRate = u.pTwistRate;
            }
          if (hasC)
            {
              shader.uniforms.propCurlAxis = u.cAxis;
              shader.uniforms.propCurlAmp = u.cAmp;
              shader.uniforms.propCurlRate = u.cRate;
              shader.uniforms.propCurlLobes = u.cLobes;
              shader.uniforms.propCurlWave = u.cWave;
              shader.uniforms.propCurlYFloor = u.cYFloor;
              shader.uniforms.propCurlYSoft = u.cYSoft;
              shader.uniforms.propCurlDFloor = u.cDFloor;
              shader.uniforms.propCurlDSoft = u.cDSoft;
            }
          var v = shader.vertexShader;
          // the normal half goes in FIRST, at <beginnormal_vertex>, so <defaultnormal_vertex> — which
          // three runs between the two anchors — carries the tilt into view space for free.
          // recomputed here rather than shared with the block below on purpose: for an unlit material
          // three wraps <beginnormal_vertex> in an `#if defined( USE_ENVMAP ) || defined( USE_SKINNING )`,
          // so anything left in a local there does not exist by the time <begin_vertex> runs
          if (lit && hasA)
            v = StringTools.replace(v, '#include <beginnormal_vertex>',
              '#include <beginnormal_vertex>\n' +
              // BRACED. both anchors are inside main(), so the two blocks share one scope and the
              // second redeclares the first's locals — a plain GLSL redefinition error, which three
              // reports and then draws with an invalid program: the prop is submitted every frame
              // (measured at 60 renderBufferDirect calls a second) and rasterizes nothing at all
              '  {\n' +
              phase +
              wave +
              // the sway's OWN tilt: d(offset)/dy, so the shading normal follows the surface the
              // displacement below just moved rather than staying with the pose it left
              '  float propH = clamp( ( position.y - propBase ) / propSpan, 0.001, 1.0 );\n' +
              '  vec2 propTilt = propWave * propAmp * propBend * pow( propH, propBend - 1.0 ) / propSpan;\n' +
              '  objectNormal.xz -= propTilt * objectNormal.y;\n' +
              // and the ripple, which displaces NOTHING — a faster, finer disturbance that exists
              // only to move where the highlight sits. frequencies are per prop-height so they do not
              // change meaning with the row's `h`
              '  objectNormal.xz += propSheen * vec2(\n' +
              '    sin( position.y * 5.3 / propSpan + propTime * propSheenRate ),\n' +
              '    cos( position.x * 4.7 / propSpan - propTime * propSheenRate * 1.13 ) );\n' +
              '  objectNormal = normalize( objectNormal );\n' +
              '  }');
          // and the displacement, BEFORE <project_vertex> — which also means SewerMask samples the
          // moved position, since its vSewerMask is built from `transformed` after that chunk.
          // the swell goes in AFTER the sway so it scales a body that has already leaned, which is
          // the right order: a lean of an inflated body and an inflation of a leaned one differ only
          // in the second order, but only this one keeps the axis the swell turns about vertical
          v = StringTools.replace(v, '#include <begin_vertex>',
            '#include <begin_vertex>\n' +
            (hasA ?
              '  {\n' +
              phase +
              wave +
              '  transformed.xz += propWave * propAmp * propWeight( position.y );\n' +
              '  }\n' : '') +
            (hasP ? swell : '') +
            (hasC ? curl : ''));
          shader.vertexShader = decl + v;
        };
      // carry forward the marks of whatever hook we just wrapped. BOTH tests above read the
      // OUTERMOST hook, so a marker that got chained over reads as absent and its owner re-patches —
      // and since it then wraps US, our own mark disappears too and we re-patch on the next frame.
      // that is a mutual loop, one round per frame, and every round is a NEW program: measured live
      // at a 21-deep key (`sewerMaskspropAnimL` repeated) and 95 -> 129 programs in four seconds
      if (prev != null)
        for (f in Reflect.fields(prev))
          Reflect.setField(hook, f, Reflect.field(prev, f));
      hook.propAnim = true;
      mat.onBeforeCompile = hook;
      // three keys its program cache on base material params, NOT on onBeforeCompile — without a key
      // of our own an animated program could be handed to an identical still material, and the lit
      // and unlit forms above would collide with each other. WHICH HALVES are present is in the key
      // for the same reason: they are emitted conditionally, so a sway-only and a pulse-only prop
      // are two different sources. CHAINED, because the props' solid and ghost materials already
      // carry SewerMask's hook and its key
      mat.customProgramCacheKey = function()
        return (prevKey != null ? Std.string(Reflect.callMethod(mat, prevKey, [])) : '') +
          'propAnim' + (hasA ? 'S' : '') + (hasP ? 'U' : '') + (hasC ? 'C' : '') + (lit ? 'L' : 'P');
      mat.needsUpdate = true;
    }
}
