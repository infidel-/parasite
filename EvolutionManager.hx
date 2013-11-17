// parasite evolution manager

import EvolutionConst;


class EvolutionManager
{
  var game: Game;
  var player: Player;

  var _list: List<Improv>; // list of known improvements (that can be of level 0)
  var _listPaths: List<Improv>; // list of known improvements (that can be of level 0)

  public function new(p: Player, g: Game)
    {
      player = p;
      game = g;

      _list = new List<Improv>();
    }


// player action (called from the EvolutionWindow)
  public function action(id: String)
    {
      var actionName = id.substr(0, id.indexOf('.'));
      var actionID = id.substr(id.indexOf('.') + 1);

      if (actionName == 'setPath')
//      else if (actionName == 'set')

      trace(actionName + ' ' + actionID);
    }


// get improvement level
  public function getLevel(id: String): Int
    {
      for (imp in _list)
        if (imp.id == id)
          return imp.level;

      return 0;
    }


// get full list
  public function getList(): List<Improv>
    {
      return _list;
    }
}

typedef Improv =
{
  var id: String; // improvement string ID
  var level: Int; // improvement level
  var ep: Int; // evolution points
}
