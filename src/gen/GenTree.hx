// the generation tree walker
//
// the entire engine is `build`: hand each node to the filler for its kind, let that filler write
// cells and push children, then walk the children it pushed. Every level of area generation is the
// same operation at a different scale, which is the whole point of the shape — an area dividing into
// blocks and a room dividing into furniture runs are one function apart, not two subsystems.
//
// the walk is BREADTH-FIRST and that is load-bearing. Depth-first would finish a whole building
// before the neighbouring park exists, so a filler could not ask what is next to it; breadth-first
// means every node at one level is on the grid before any node of the next level runs, which is the
// same reason game.AreaGenerator's wilderness lays the highway before the trees.

package gen;

class GenTree
{
  // how deep the walk may go before it is a bug rather than a deep tree. the facility reaches 3
  // (area -> block -> room -> furniture run), so this is slack, not a limit anyone designs against
  public static inline var MAX_DEPTH = 8;

// make a root node covering a whole rect
  public static function root(kind: String, x1: Int, y1: Int, x2: Int, y2: Int): _GenNode
    {
      return {
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        kind: kind,
        children: [],
      };
    }

// make a child node and attach it to its parent, in one call. the parent's children array is what
// the walk reads next, so a filler that builds a node but forgets to attach it silently does nothing
  public static function add(parent: _GenNode, kind: String,
      x1: Int, y1: Int, x2: Int, y2: Int): _GenNode
    {
      var node = root(kind, x1, y1, x2, y2);
      parent.children.push(node);
      return node;
    }

// walk the tree breadth-first, handing every node to `fill`.
//
// `fill` writes whatever that node is into the grid and pushes the children it divides into; this
// returns once no node pushed any. the depth guard is against a filler that pushes a child of its
// own kind covering its own rect, which recurses forever and is the one way to write this wrong
  public static function build(node: _GenNode, fill: _GenNode -> Void)
    {
      var level = [node];
      var depth = 0;
      while (level.length > 0)
        {
          if (depth > MAX_DEPTH)
            {
              trace('GenTree.build(): depth ' + depth + ' exceeded, check for a filler ' +
                'pushing a child of its own kind');
              return;
            }
          var next = [];
          for (n in level)
            {
              fill(n);
              for (c in n.children)
                next.push(c);
            }
          level = next;
          depth++;
        }
    }

// every leaf of the tree, in walk order. a leaf is a node nothing divided further, which is where
// the actual contents of an area end up
  public static function leaves(node: _GenNode): Array<_GenNode>
    {
      var out = [];
      walk(node, function(n)
        {
          if (n.children.length == 0)
            out.push(n);
        });
      return out;
    }

// every node of this kind, at any depth
  public static function all(node: _GenNode, kind: String): Array<_GenNode>
    {
      var out = [];
      walk(node, function(n)
        {
          if (n.kind == kind)
            out.push(n);
        });
      return out;
    }

// the first node of this kind, or null
  public static function find(node: _GenNode, kind: String): _GenNode
    {
      var list = all(node, kind);
      return (list.length > 0 ? list[0] : null);
    }

// call f on this node and every node under it. the tree is already built by the time anything calls
// this, so the order is plain depth-first and nothing depends on it
  public static function walk(node: _GenNode, f: _GenNode -> Void)
    {
      f(node);
      for (c in node.children)
        walk(c, f);
    }

// does this node contain that cell?
  public static inline function contains(node: _GenNode, x: Int, y: Int): Bool
    {
      return (x >= node.x1 &&
        x <= node.x2 &&
        y >= node.y1 &&
        y <= node.y2);
    }

// do these two nodes share any cell? the check gen.Quota's dealt blocks must never fail, and what
// tools/genrun.mjs asserts over every generated area
  public static inline function overlaps(a: _GenNode, b: _GenNode): Bool
    {
      return !(a.x2 < b.x1 ||
        b.x2 < a.x1 ||
        a.y2 < b.y1 ||
        b.y2 < a.y1);
    }

  public static inline function width(node: _GenNode): Int
    return node.x2 - node.x1 + 1;

  public static inline function height(node: _GenNode): Int
    return node.y2 - node.y1 + 1;
}
