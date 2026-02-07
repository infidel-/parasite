// taken from http://code.google.com/p/apath/, GPLv2

package aPath;
class Node {
  public var x: Int;
  public var y: Int;
  public var cost: Int;
  public var parent: Node;
  public var open: Bool;
  public var close: Bool;
  public var gCost: Int;
  public var hCost: Int;
  public var fCost: Int;
  private var engine: Engine;

// constructor of the class
  public function new(x: Int, y: Int, cost: Int, e: Engine)
    {
      this.x = x;
      this.y = y;
      this.cost = cost;
      this.engine = e;
      clean();
    }


// clean node before new pass
  public inline function clean()
    {
      open = false;
      close = false;
      parent = null;
      gCost = 999999;
      hCost = 0;
      fCost = 999999;
    }

// get the list of eight adjacent nodes of this node
  static var adjacent = [[1, 0], [1, -1], [0, -1], [-1, -1], [-1, 0], [-1, 1], [0, 1], [1, 1]];
  public function getAdjacentNodes(map: Array<Array<Node>>)
      {
        var list = [];
        for (i in adjacent)
          {
            if (!engine.area.isWalkable(x + i[0], y + i[1]))
              continue;

            var node = map[x + i[0]][y + i[1]];

            if (engine.area.hasAI(x + i[0], y + i[1]) && node != engine.endNode)
              continue;

            if (node != null && !node.close)
              list.push(node);
          }
        return list;
      }

// get current g cost
  public inline function getG(): Int
    {
      return gCost;
    }

// get current h cost
  public inline function getH(): Int
    {
      return hCost;
    }

// get current f cost
  public inline function getF(): Int
    {
      return fCost;
    }
}
