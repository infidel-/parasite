// per-cell tile data including decoration list

package tiles;

typedef Tile = {
  var id: Int;
  // cached value based on tile type and objects on it
  var canSeeThrough: Bool;
  // cached walkability based on tile type and objects on it
  var isWalkable: Bool;
  var decoration: Array<tiles.Decoration>;
}
