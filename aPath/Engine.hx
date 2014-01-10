// taken from http://code.google.com/p/apath/, GPLv2

package aPath;
import aPath.Node;
class Engine {
	public var map:Array<Array<Node>>;
	public var startNode:Node;
	public var endNode:Node;
    public var area: Area;
	public var width: Int;
	public var height: Int;
	
	public function new(a: Area, w: Int, h: Int){
		this.map = new Array();
        area = a;
		width = w;
		height = h;

		for(xi in 0...w)
          {
			map[xi] = []; 
			for(yi in 0...h)
			  map[xi][yi] = new Node(xi, yi, 10, this);
		  }
	}


    public function clean()
      {
        for (y in 0...height)
          for (x in 0...width)
            map[x][y].clean();
      }

	public function getMap():Array<Array<Node>> {
		return this.map;
	}

	public function getPath(x1: Int, y1: Int, x2: Int, y2: Int):Array<Node> {
		var openList = new Array();
		var closeList = new Array();

        startNode = map[x1][y1];
        endNode = map[x2][y2];

		var currentNode:Node = this.startNode;
		while(true){
			var adjacent = currentNode.getAdjacentNodes(map);
			adjacent.sort(function(node_a, node_b){
				var num = node_a.getF() - node_b.getF();
				if(num == 0){
					num = node_a.getH()-node_b.getH();
				}
				return num;
			});
			for(node in adjacent){
				if(!node.open){
					node.open = true;
					node.parent = currentNode;
				}
			}
			currentNode.close = true;
			if(currentNode == endNode){
				break;
			}	
			currentNode = adjacent[0];
		}
		var path:Array<Node> = new Array();
		var currentNode = this.endNode;
		while(true){
			path.push(currentNode);
			currentNode = currentNode.parent;
			if(currentNode == startNode){
				break;
			}
		}
		path.reverse();
		return path;
	}

}
