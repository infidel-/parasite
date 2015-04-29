// player goals

package game;

import const.Goals;

class Goals
{
  var game: Game;
  var _listCurrent: List<_Goal>; // list of current goals
  var _listCompleted: List<_Goal>; // list of completed goals

  public function new(g: Game)
    {
      game = g;
      _listCurrent = new List();
      _listCompleted = new List();
    }


// iterator for current goals
  public function iteratorCurrent()
    {
      return _listCurrent.iterator();
    }


// iterator for completed goals
  public function iteratorCompleted()
    {
      return _listCompleted.iterator();
    }


// receive a new goal
  public function receive(id: _Goal)
    {
      // check if this goal already completed or received
      if (Lambda.has(_listCompleted, id) || Lambda.has(_listCurrent, id))
        return;

      _listCurrent.add(id);

      var info = getInfo(id);
      if (info == null)
        throw "No such goal: " + id;

      if (info.messageReceive != null) // message on receiving
        game.message(info.messageReceive);

      if (info.isHidden == null || info.isHidden == false)
        game.log('You have received a new goal: ' + info.name + '.');
    }


// complete a goal
  public function complete(id: _Goal)
    {
      // check if player has this goal
      if (!Lambda.has(_listCurrent, id))
        return;

      _listCurrent.remove(id);
      _listCompleted.add(id);

      var info = getInfo(id);
      if (info.isHidden == null || info.isHidden == false)
        game.log('You have completed a goal: ' + info.name + '.');

      if (info.messageComplete != null) // completion message
        game.message(info.messageComplete);

      // call completion hook
      if (info.onComplete != null)
        info.onComplete(game, game.player);
    }


// does player has this goal? 
  public inline function has(id: _Goal): Bool
    {
      return (Lambda.has(_listCurrent, id));
    }


// did player complete this goal?
  public inline function completed(id: _Goal): Bool
    {
      return (Lambda.has(_listCompleted, id));
    }


// get goal info 
  public function getInfo(id: _Goal): GoalInfo
    {
      // common goals
      var info = const.Goals.map.get(id);
      if (info != null)
        return info;

      // scenario-specific goals
      var info = game.timeline.getGoals().get(id);
      if (info != null)
        return info;
    
      throw 'no such goal: ' + id;
    }

}
