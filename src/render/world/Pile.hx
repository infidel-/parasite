package render.world;

// how a pile lays its pieces (render.world.StreetProps.deal)
enum PileKind
{
  HEAP;  // scattered over the spot, the `back` parts at the wall's foot, the `front` ones spilt forward
  STACK; // a few lying flat one on another, the rest stood on edge leaning back on them or lying beside
  LOAD;  // inside the prop's own basket (GroundProp.path), over `bed`
}

// a street pile dealt per cell from separate pieces (GroundProp.pile), so no two heaps are the same:
// the pieces, how many and how they are laid. a modelled-whole heap was one heap on every street
typedef Pile = {
  kind:PileKind,         // how the pieces are laid
  parts:Array<PilePart>, // the pieces it deals from
  min:Int,               // fewest pieces dealt (0 = some cells get none, an empty cart)
  max:Int,               // most
  ?bed:PileBed,          // LOAD: the basket floor they are dealt over
};
