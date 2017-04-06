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
  
  public function new(a: game.AreaGame, w: Int, h: Int){
      area = a;
      width = w;
      height = h;

      map = []; 
      for(xi in 0...w)
        {
          map[xi] = []; 
          for(yi in 0...h)
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

      var openList = []; 
      var closeList = [];

      startNode = map[x1][y1];
      endNode = map[x2][y2];

      var currentNode = startNode;
      while (true)
        {
          if (currentNode == null)
            return null;
          var adjacent = currentNode.getAdjacentNodes(map);
          adjacent.sort(function(node_a, node_b)
            {
              var num = node_a.getF() - node_b.getF();
              if (num == 0)
                num = node_a.getH() - node_b.getH();
              
              return num;
            });

          for (node in adjacent)
            if (!node.open)
              {
                node.open = true;
                node.parent = currentNode;
              }
          currentNode.close = true;
          if (currentNode == endNode)
            break;

          currentNode = adjacent[0];
        }

      var path = [];
      var currentNode = endNode;
      while (true)
        {
          path.push(currentNode);
          currentNode = currentNode.parent;
          if (currentNode == startNode)
            break;
          
        }
      path.reverse();
      return path;
  }
}
