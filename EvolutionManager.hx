// parasite evolution manager

import ConstEvolution;


class EvolutionManager
{
  var game: Game;
  var player: Player;

  public var isTaskPath: Bool; // is current task path?
  public var taskID: String; // string id of currently evolving path/improvement
  var _list: List<Improv>; // list of known improvements (that can be of level 0)
  var _listPaths: List<Path>; // list of paths (evolution progress)

  public function new(p: Player, g: Game)
    {
      player = p;
      game = g;

      _list = new List<Improv>();
      _listPaths = new List<Path>();
      taskID = '';
      isTaskPath = false;

      for (p in ConstEvolution.paths) // we may have hidden paths later ;)
        _listPaths.add({
          id: p.id,
          ep: 0,
          level: 0,
          info: ConstEvolution.getPathInfo(p.id)
          });
    }


// end of turn
  public function turn()
    {
      // no tasks
      if (taskID == '')
        return;

      player.energy -= 5;
      if (isTaskPath) // path evolution
        {
          var path = getPath(taskID);
          path.ep += 10;

          // evolution complete
          if (path.ep >= ConstEvolution.epCostPath[path.level])
            {
              var imp = openImprov(taskID);
              if (imp == null)
                {
                  player.log('You have followed this evolution path to the end.',
                    Const.COLOR_EVOLUTION);
                  path.ep = 0;
                  taskID = '';
                  Const.todo('I probably need to disable this path at that moment.');
                  return;
                }

              player.log('Following the path of ' + path.info.name +
                ' you now possess the knowledge about ' + imp.info.name + '.',
                Const.COLOR_EVOLUTION);
              path.ep = 0;
              path.level++;
              taskID = '';
            }
        }

      else // upgrade improvement
        {
          var imp = getImprov(taskID);
          imp.ep += 10;

          // upgrade complete
          if (imp.ep >= ConstEvolution.epCostImprovement[imp.level])
            {
              imp.level++;
              player.log('You have improved your understanding of ' + imp.info.name +
                ' to level ' + imp.level + '.', Const.COLOR_EVOLUTION);

              // clear
              imp.ep = 0;
              taskID = '';
            }
        }
    }

  
// open improvement on that path
  function openImprov(path: String): Improv
    {
      // get list of improvs on that path that player does not yet have
      var tmp = [];
      for (imp in ConstEvolution.improvements)
        if (imp.path == path && !isKnown(imp.id))
          tmp.push(imp.id);

      // no improvs left on that path
      if (tmp.length == 0)
        return null;

      // get random improv
      var index = Std.random(tmp.length);
      var impID = tmp[index];
      
      var imp = addImprov(impID);
      return imp;
    }


// add improvement to list
  public inline function addImprov(id: String): Improv
    {
      var imp = {
        id: id,
        level: 0,
        ep: 0,
        info: ConstEvolution.getInfo(id)
        };
      _list.add(imp);
      return imp;
    }


// player action (called from the EvolutionWindow)
  public function action(id: String)
    {
      var actionName = id.substr(0, id.indexOf('.'));
      var actionID = id.substr(id.indexOf('.') + 1);

      taskID = actionID;
      if (actionName == 'setPath')
        isTaskPath = true;
      else if (actionName == 'set')
        isTaskPath = false;

//      trace(actionName + ' ' + actionID);
    }


// is this improvement known?
  public function isKnown(id: String): Bool
    {
      for (imp in _list)
        if (imp.id == id)
          return true;

      return false;
    }


// get improvement
  public function getImprov(id: String): Improv
    {
      for (imp in _list)
        if (imp.id == id)
          return imp;

      return null;
    }


// get current improvement params
  public function getParams(id: String): Dynamic
    {
      var imp = getImprov(id);
      if (imp == null)
        return null;

      return imp.info.levelParams[imp.level];
    }


// get improvement level
  public function getLevel(id: String): Int
    {
      for (imp in _list)
        if (imp.id == id)
          return imp.level;

      return 0;
    }


// get path object
  public function getPath(id: String): Path
    {
      for (p in _listPaths)
        if (p.id == id)
          return p;

      return null;
    }


// get full list
  public function getList(): List<Improv>
    {
      return _list;
    }


// get full list of paths
  public function getPathList(): List<Path>
    {
      return _listPaths;
    }


// get current evolution direction info
  public function getEvolutionDirectionInfo(): String
    {
      if (taskID == '')
        return "<font color='#FF0000'>None</font>";
      else if (isTaskPath)
        return ConstEvolution.getPathInfo(taskID).name;
      else return ConstEvolution.getInfo(taskID).name;
    }
}

typedef Improv =
{
  var id: String; // improvement string ID
  var level: Int; // improvement level
  var ep: Int; // evolution points
  var info: ImprovInfo; // improvement info link
}


typedef Path =
{
  var id: String; // string ID
  var level: Int; // path level is mainly a convenience var, equals number of opened improvements on that path
  var ep: Int; // evolution points
  var info: PathInfo; // path info link
}
