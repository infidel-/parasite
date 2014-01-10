// taken from http://code.google.com/p/apath/, GPLv2

package aPath;
class Node {
	public var x:Int;
	public var y:Int;
	public var cost:Int;
	public var parent:Node;
	public var open:Bool;
	public var close:Bool;
	private var engine:Engine;

	//Constructor of the class
	public function new(x:Int, y:Int, cost:Int, e: Engine) {
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
    }

	//Get the list of eight adjacent nodes of this node
	static var adjacent = [[1,0],[1,-1],[0,-1],[-1,-1],[-1,0],[-1,1],[0,1],[1,1]];
	public function getAdjacentNodes(map:Array<Array<Node>>) 
      {
		var list = new Array();
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


	//get a distance from startNode
	public function getG():Int {
		var endNode = engine.endNode;
		var xDistance = cast Math.abs(endNode.x - x);
		var yDistance = cast Math.abs(endNode.y - y);
		var G:Int;
		if (xDistance > yDistance) {
			G = 14*yDistance + 10*(xDistance-yDistance);
		}else{   
			G = 14*xDistance + 10*(yDistance-xDistance);
		}
		return G;
	}
	//get a distance to endNode
	public function getH():Int {
		var endNode = engine.endNode;
		var xDistance = cast Math.abs(endNode.x - x);
		var yDistance = cast Math.abs(endNode.y - y);
		var H:Int;
		if (xDistance > yDistance) {
			H = 14*yDistance + 10*(xDistance-yDistance);
		}else{   
			H = 14*xDistance + 10*(yDistance-xDistance);
		}
		return H;
	}
	//F = G + H
	public function getF():Int{
		return getH() + getG();
	}
}
