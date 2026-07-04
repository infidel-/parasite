package render.particles;

// the paint surfaces handed to a Particle3D each frame: the lit billboard/decal pool (sprites)
// and the unlit additive bright-FX pool (beams). a particle draws onto whichever it needs
typedef Paint3D = {
  sprites: Sprites,
  beams: Beams,
}
