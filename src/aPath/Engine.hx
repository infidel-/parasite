// taken from http://code.google.com/p/apath/, GPLv2

package aPath;

import aPath.Node;

class Engine 
{
  public var map: Array<Array<Node>>;
  public var startNode: Node;
  public var endNode: Node;
  public var area: game.AreaGame;
  public var width: Int;
  public var height: Int;
  
  public function new(a: game.AreaGame, w: Int, h: Int)
    {
      area = a;
      width = w;
      height = h;

      map = []; 
      for (xi in 0...w)
        {
          map[xi] = []; 
          for (yi in 0...h)
            map[xi][yi] = new Node(xi, yi, 10, this);
        }
    }


// main call: get a path x1, y1 -> x2, y2
  public function getPath(x1: Int, y1: Int, x2: Int, y2: Int): Array<Node>
    {
      if (x1 == x2 && y1 == y2)
        return null;

      // clean nodes before another pass
      for (y in 0...height)
        for (x in 0...width)
          map[x][y].clean();

      startNode = map[x1][y1];
      endNode = map[x2][y2];

      // initialize start node and open list
      var openList = [];
      startNode.gCost = 0;
      startNode.hCost = heuristic(startNode, endNode);
      startNode.fCost = startNode.gCost + startNode.hCost;
      startNode.open = true;
      openList.push(startNode);

      while (openList.length > 0)
        {
          // pick the best open node by f then h
          var currentIndex = 0;
          var currentNode = openList[0];
          for (i in 1...openList.length)
            {
              var node = openList[i];
              if (node.fCost < currentNode.fCost ||
                  (node.fCost == currentNode.fCost &&
                   node.hCost < currentNode.hCost))
                {
                  currentNode = node;
                  currentIndex = i;
                }
            }
          openList.splice(currentIndex, 1);
          currentNode.open = false;
          currentNode.close = true;

          // path found
          if (currentNode == endNode)
            return buildPath();

          // expand neighbors
          var adjacent = currentNode.getAdjacentNodes(map);
          for (node in adjacent)
            {
              if (node.close)
                continue;

              var nextG = currentNode.gCost + stepCost(currentNode, node);
              if (!node.open || nextG < node.gCost)
                {
                  node.parent = currentNode;
                  node.gCost = nextG;
                  node.hCost = heuristic(node, endNode);
                  node.fCost = node.gCost + node.hCost;

                  if (!node.open)
                    {
                      node.open = true;
                      openList.push(node);
                    }
                }
            }
        }

      return null;
    }

// build path from end node to start node
  function buildPath(): Array<Node>
    {
      var path = [];
      var currentNode = endNode;
      while (currentNode != startNode)
        {
          path.push(currentNode);
          currentNode = currentNode.parent;
          if (currentNode == null)
            return null;
        }
      path.reverse();
      return path;
    }

// get movement cost between adjacent nodes
  inline function stepCost(a: Node, b: Node): Int
    {
      var dx = Math.abs(a.x - b.x);
      var dy = Math.abs(a.y - b.y);
      if (dx == 1 && dy == 1)
        return 14;
      return 10;
    }

// get octile distance heuristic between nodes
  inline function heuristic(a: Node, b: Node): Int
    {
      var dx = Std.int(Math.abs(a.x - b.x));
      var dy = Std.int(Math.abs(a.y - b.y));
      if (dx > dy)
        return 14 * dy + 10 * (dx - dy);
      return 14 * dx + 10 * (dy - dx);
    }
}
