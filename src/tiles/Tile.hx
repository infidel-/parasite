// per-cell tile data including decoration list

package tiles;

typedef Tile = {
  var id: Int;
  // cached value base d on tile type and objects on it
  var canSeeThrough: Bool;
  var decoration: Array<tiles.Decoration>;
}
