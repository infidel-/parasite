package cult.base;

// what a cult base organ just went through, for the 3D view's one-shot animation of it
// (render.particles.OrganFx3D)
enum OrganFxKind
{
  DESTROY; // shudders, slumps to its ruin's height bleeding, then swaps to the ruin
  REPAIR;  // a broken organ rises from its ruin's height while flesh-pink sinew knits into it
  MEND;    // a damaged one only takes the sinew
  UPGRADE; // one heartbeat swell, a glow at its crown and a ring across the floor
  BIRTH;   // Cor Nefandum tears up out of the floor as the base is born, the place quaking
}
