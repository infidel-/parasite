# Flesh shaders: the variants not shipped (yet)

Four "fleshy" surface variants were tried on the cult base organs (2026-11-14) in a standalone three.js
harness that ported the shipped `PropShader` motion and the habitat rig (ACES 1.5, bloom 0.25/0.1/0.9,
camera `CAMERA_SEWER.near`). **A, the capillary throb, shipped** as the `flesh` column
(`PropFlesh` in `render/world/ObjModels.hx`, the block in `render/world/PropGlow.hx`). B, C and D are
kept here, GLSL and knobs, so they can be wired later without redoing the harness. The harness itself
lived in a session scratchpad and is gone.

None costs a draw call, a pass or a texture. All four were measured on the Cor Nefandum Meshy cut off
`cor-nefandum-3`. Knob values are what the harness fitted. A shipped at **0.04 glow** against the
harness's 0.7: the game reads emissive far hotter on these dark bodies (linear albedo ~0.03), so expect
any emissive term below to want a similar cut when it goes live.

## Shared frame and helpers

Everything is in the prop's LOCAL frame, as fractions of its own height (`propSpan`, `propBase`,
`propCentre` = the box's XZ centre), the `PropShader`/`PropGlow` rule. `vFleshPos` is `position`
(not `transformed`), so patterns stay glued to the material while the body breathes. The clock is
BASE_MS turns. The per-instance phase in the harness was raw (`instanceMatrix[3].x * 0.37 + .z * 0.29`);
inside `PropGlow` use `vGlowPh * 6.2832`, which is pre-hashed for precision.

```glsl
// lub-dub: two gaussian kicks per 2*PI of phase, 1.0 and 0.55 tall, rest ~0
float fleshBeat( float ph )
{
  float f = fract( ph * 0.15915 );
  float a = f - 0.08;
  float b = f - 0.30;
  return exp( -a * a * 60.0 ) + 0.55 * exp( -b * b * 60.0 );
}
// iq value noise, 8 hashes + trilinear: ~40 ALU
float fleshHash( vec3 p )
{
  p = fract( p * 0.3183099 + 0.1 );
  p *= 17.0;
  return fract( p.x * p.y * p.z * ( p.x + p.y + p.z ) );
}
const mat3 FLESH_ROT = mat3( 0.00, 0.80, 0.60, -0.80, 0.36, -0.48, -0.60, -0.48, 0.64 );
float fleshNoise( vec3 x )
{
  vec3 i = floor( x );
  vec3 f = fract( x );
  f = f * f * ( 3.0 - 2.0 * f );
  return mix( mix( mix( fleshHash( i ), fleshHash( i + vec3( 1, 0, 0 ) ), f.x ),
                   mix( fleshHash( i + vec3( 0, 1, 0 ) ), fleshHash( i + vec3( 1, 1, 0 ) ), f.x ), f.y ),
              mix( mix( fleshHash( i + vec3( 0, 0, 1 ) ), fleshHash( i + vec3( 1, 0, 1 ) ), f.x ),
                   mix( fleshHash( i + vec3( 0, 1, 1 ) ), fleshHash( i + vec3( 1, 1, 1 ) ), f.x ), f.y ), f.z );
}
```

Anchors: *albedo* blocks go after `<map_fragment>` (diffuseColor is linear albedo; `fleshAlb` is a
copy taken there), *roughness* after `<roughnessmap_fragment>`, *emissive* at `<emissivemap_fragment>`
(`PropGlow`'s anchor), *vertex* after `<begin_vertex>` on `transformed`, braced, after `PropShader`'s
swell. `fleshM` is a float the block sets (the harness's mask debug view showed it).

## B. Veins under skin — superseded on the new Cor

A procedural vein net (two octaves of ridged value noise in object space) darkens pale skin in a
bruised purple and flushes red on the heartbeat. A blood-red fresnel rim breathes with the swell.
**Verdict:** the new Cor paints its own veins, so this is a second, unrelated vein pattern over them,
near-invisible at game scale, and its rim makes bone read as skin. Could suit a PLAIN pale organ.
Cost: frag ~140 ALU, 0 fetches.

```glsl
uniform vec4 veinNet;   // scale (cycles per span), sharp, depth, skin lum lo
uniform vec3 veinTint;  // multiply on the skin under a vein
uniform vec4 veinBeat;  // rate, glow, rim, rim breath
uniform vec3 veinRim;
float veinV;
float veinSkin;
// albedo
  {
    // rotated off the lattice axes: value noise leaves axis-aligned streaks
    vec3 vp = FLESH_ROT * ( vFleshPos / propSpan * veinNet.x );
    float n1 = fleshNoise( vp );
    float n2 = fleshNoise( FLESH_ROT * vp * 2.3 + n1 * 1.7 );
    float vb = fleshBeat( propTime * veinBeat.x + vFleshIPh );
    float sh = veinNet.y * ( 1.0 - 0.45 * vb ); // the net swells on the beat
    veinV = pow( 1.0 - abs( n1 * 2.0 - 1.0 ), sh ) + 0.6 * pow( 1.0 - abs( n2 * 2.0 - 1.0 ), sh * 1.4 );
    float l = dot( diffuseColor.rgb, vec3( 0.2126, 0.7152, 0.0722 ) );
    veinSkin = smoothstep( veinNet.w, veinNet.w * 2.0, l );
    fleshM = clamp( veinV, 0.0, 1.0 ) * veinSkin;
    diffuseColor.rgb = mix( diffuseColor.rgb, diffuseColor.rgb * veinTint, fleshM * veinNet.z );
  }
// emissive
  {
    float vb = fleshBeat( propTime * veinBeat.x + vFleshIPh );
    totalEmissiveRadiance += vec3( 0.55, 0.01, 0.04 ) * fleshM * vb * veinBeat.y;
    float ndv = abs( dot( normal, normalize( vViewPosition ) ) );
    float rim = pow( 1.0 - ndv, 3.0 );
    float breath = 0.5 + 0.5 * sin( propTime * 0.18 + vFleshIPh ); // the shipped swell's own phase
    totalEmissiveRadiance += veinRim * rim * ( veinBeat.z + veinBeat.w * breath ) * fleshAlb.r;
  }
```

Knobs: `veinNet` (7.0, 40.0, 0.6, 0.10), `veinTint` (0.22, 0.10, 0.32), `veinBeat` (0.63, 0.35, 0.3, 0.4),
`veinRim` 0xff2040.

## C. Peristalsis — the best candidate to add next

A swallowing bulge climbs from the roots to the crown every ~3.4 s: a radial scale about the prop's
axis keyed on `position` only, so it cannot tear UV seams, and the tissue it passes flushes redder.
**Verdict:** works on the 2x2 fleshy organs and stacks with the heartbeat (they already breathe).
Not on the 1x1 bone pieces, which `cultOrgan` holds still by design. The cheapest variant (vert ~15
ALU, frag ~15) and the only one that moves the silhouette. Its floor matches the shipped pulse's
(0.12..0.27 of the height), so the roots stay put.

```glsl
uniform vec4 periWave;  // rate, width (span fraction), amp (radius fraction), flush
uniform float periGlow;
float periBand( float y, float iph )
{
  float c = fract( propTime * periWave.x * 0.15915 + iph * 0.1 ) * 1.5 - 0.25;
  float d = ( y - c ) / periWave.y;
  return exp( -d * d );
}
// vertex
  {
    float y = ( position.y - propBase ) / propSpan;
    float b = periBand( y, propIPh ) * smoothstep( 0.12, 0.27, y );
    vec2 d = transformed.xz - propCentre;
    transformed.xz = propCentre + d * ( 1.0 + periWave.z * b );
  }
// albedo
  fleshM = periBand( ( vFleshPos.y - propBase ) / propSpan, vFleshIPh ) *
    smoothstep( 0.12, 0.27, ( vFleshPos.y - propBase ) / propSpan );
  diffuseColor.rgb *= mix( vec3( 1.0 ), vec3( 1.0 + periWave.w, 1.0 - periWave.w * 0.5, 1.0 - periWave.w * 0.3 ), fleshM );
// emissive
  totalEmissiveRadiance += vec3( 0.6, 0.02, 0.05 ) * fleshM * periGlow * fleshAlb.r;
```

Knobs: `periWave` (0.31, 0.10, 0.06, 0.45), `periGlow` 0.5. Wiring note: the vertex half belongs in
`PropShader` (a new column beside `pulse`), the flush in `PropGlow`; both need the same band.

## D. Wet runnels — optional, garbage heap and root tips

Thin vertical runs of slime (ridged value noise stretched 12:1) slide slowly down the body: roughness
drops to 0.08 inside a run, the albedo darkens by a quarter, and a fixed overhead glint lobe catches
light without a lamp beside the organ. **Verdict:** sells the garbage heap ("wet garbage") and reads
as wet root tips on the Cor at game scale; slime runs close up. Touches gloss only, so it stacks with
anything. Untried on the blood trap, where a puddle might suit it. Cost: frag ~80 ALU, 0 fetches.

```glsl
uniform vec4 wetNet;   // freq (cycles per span), vertical stretch, flow (span per turn), coverage
uniform vec3 wetLook;  // roughness in a runnel, albedo darken, glint
float wetW;
// albedo
  {
    vec3 wp = vFleshPos / propSpan * wetNet.x;
    float n = fleshNoise( vec3( wp.x, wp.y * wetNet.y + propTime * wetNet.z * wetNet.x, wp.z ) );
    wetW = smoothstep( wetNet.w, wetNet.w + 0.1, 1.0 - abs( n * 2.0 - 1.0 ) ); // ridged: thin runs
    fleshM = wetW;
    diffuseColor.rgb *= 1.0 - wetLook.y * wetW;
  }
// roughness
  roughnessFactor = mix( roughnessFactor, wetLook.x, wetW );
// emissive
  {
    vec3 up = normalize( ( viewMatrix * vec4( 0.0, 1.0, 0.0, 0.0 ) ).xyz );
    vec3 r = reflect( -normalize( vViewPosition ), normal ); // vViewPosition points AT the camera
    float g = pow( max( dot( r, up ), 0.0 ), 8.0 );
    totalEmissiveRadiance += vec3( 1.0, 0.55, 0.62 ) * g * wetW * wetLook.z;
  }
```

Knobs: `wetNet` (10.0, 0.08, 0.001, 0.82), `wetLook` (0.08, 0.25, 0.6). Needs a lit Standard material
(roughness); on a Lambert organ only the darken and the glint apply.
