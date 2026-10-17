package render.world;

// the floor a LOAD pile is dealt over (render.world.Pile): a basket's, in its prop's own frame at the
// prop's drawn height, world units, x along the prop's model x and z toward its front
typedef PileBed = {
  x0:Float, // the floor's back-to-nose extent along x
  x1:Float,
  z0:Float, // and across it
  z1:Float,
  y:Float,  // its height off the ground
};
