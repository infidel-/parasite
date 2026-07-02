package render.world;

import citygen.CityModel.Building;
import citygen.CityModel.Tile;

// shared state for one city build, set by World.build() and read by every world
// sub-builder. buildings/tiles are read by nearly every pass; the *Seen maps are
// written by one pass each (bands/doors/windows) and read only by the checklist.
class WorldCtx {
  // all buildings in the current city
  public static var buildings:Array<Building>;
  // the tile grid of the current city (row-major)
  public static var tiles:Array<Array<Tile>>;

  // post-gen checklist: presence of each feature per building, recorded AT the render
  // chokepoints (so the check verifies what actually rendered, not a re-derivation)
  public static var winSeen:haxe.ds.ObjectMap<Building, Bool>;
  public static var doorSeen:haxe.ds.ObjectMap<Building, Bool>;
  public static var bandSeen:haxe.ds.ObjectMap<Building, Bool>;
  public static var noBackDoor:Array<Building>; // had an open back wall but no side door fit (clearance)
}
