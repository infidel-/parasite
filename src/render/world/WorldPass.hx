package render.world;

// what a render.World.build is for. a warm pass builds a throwaway city only for the programs it
// compiles and the textures it uploads, so it skips what a real build owes the player
enum WorldPass
{
  // a city the player walks: every building, and the Check audit after it
  REAL;
  // the boot warm's first city: render.CityWarm.representatives of the buildings, full ground, no audit
  WARM;
  // a further boot-warm city: as WARM, and the ground only loads its textures — its one program is
  // already in from the first city
  WARM_NO_GROUND;
}
