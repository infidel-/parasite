package render.particles;

// the paint surfaces handed to a Particle3D each frame: the lit billboard/decal pool (sprites),
// the unlit additive bright-FX pool (beams: tracers/flash), and the camera-facing soft-ember pool
// (sparks: impact sprays). a particle draws onto whichever it needs
typedef Paint3D = {
  sprites: Sprites,
  beams: Beams,
  sparks: Sparks,
}
