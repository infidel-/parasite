// player goals

package game;

import ai.AI;

class Goals extends _SaveObject
{
  var game: Game;
  var _listCurrent: List<_Goal>; // list of current goals
  var _listCompleted: List<_Goal>; // list of completed goals
  var _listFailed: List<_Goal>; // list of failed goals

  public function new(g: Game)
    {
      game = g;
      _listCurrent = new List();
      _listCompleted = new List();
      _listFailed = new List();
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


// iterator for failed goals
  public function iteratorFailed()
    {
      return _listFailed.iterator();
    }

// TURN: goals turn functions
  public function turn()
    {
      for (goal in _listCurrent)
        {
          var info = getInfo(goal);
          if (info.onTurn != null)
            {
//              game.debug(info.id + ' onTurn()');
              info.onTurn(game, game.player);
            }
        }
    }

// called on area enter
  public function onEnter()
    {
      for (goal in _listCurrent)
        {
          var info = getInfo(goal);
          if (info.onEnter == null)
            continue;
          info.onEnter(game);
        }
    }

// called pre-leave area (by normal means)
// if it returns false, leaving is not allowed
  public function leaveAreaPre(): Bool
    {
      for (goal in _listCurrent)
        {
          var info = getInfo(goal);
          if (info.leaveAreaPre == null)
            continue;
          if (!info.leaveAreaPre(game, game.player, game.area))
            return false;
        }
      return true;
    }

// called in ai constructor
// NOTE: must be inserted manually in all AI classes
  public function aiInit(ai: AI)
    {
      for (goal in _listCurrent)
        {
          var info = getInfo(goal);
          if (info.aiInit == null)
            continue;
          info.aiInit(game, ai);
        }
    }

// receive a new goal
// silent: 0 - no, 1 - 
  public function receive(id: _Goal, ?silent: _GoalSilent = SILENT_NONE)
    {
      // check if this goal already completed or received
      if (Lambda.has(_listCompleted, id) || Lambda.has(_listCurrent, id))
        return;
      if (!game.importantMessagesEnabled)
        silent = SILENT_ALL;

      _listCurrent.add(id);

      var info = getInfo(id);
      if (info == null)
        throw "No such goal: " + id;

      // message on receiving
      if (silent != SILENT_ALL &&
          info.messageReceive != null)
        {
          var img = ('event/' + id + '_receive').toLowerCase();
          game.message(info.messageReceive, img);
        }

      if (info.isHidden == null || info.isHidden == false)
        if (silent == SILENT_NONE)
          game.log('You have received a new goal: ' + info.name + '.',
            COLOR_GOAL);

      // call receive hook
      if (info.onReceive != null)
        info.onReceive(game, game.player);
    }


// complete a goal
  public function complete(id: _Goal, ?silent: _GoalSilent = SILENT_NONE)
    {
      // check if player has this goal
      if (!Lambda.has(_listCurrent, id))
        return;
      if (!game.importantMessagesEnabled)
        silent = SILENT_ALL;

      _listCurrent.remove(id);
      _listCompleted.add(id);

      var info = getInfo(id);
      if (info.isHidden == null || info.isHidden == false)
        if (silent == SILENT_NONE)
          game.log('You have completed a goal: ' + info.name + '.',
            COLOR_GOAL);

      // completion message
      if (silent != SILENT_ALL &&
          info.messageComplete != null)
        {
          var img = '';
          if (info.imageComplete != null)
            img = info.imageComplete;
          else img = ('event/' + id + '_complete').toLowerCase();
          game.message(info.messageComplete, img);
        }

      // call completion hook
      if (info.onComplete != null)
        info.onComplete(game, game.player);
    }


// fail this goal
  public function fail(id: _Goal)
    {
      // check if this goal already completed or not received
      if (Lambda.has(_listCompleted, id) || !Lambda.has(_listCurrent, id))
        return;

      _listCurrent.remove(id);
      _listFailed.add(id);

      var info = getInfo(id);
      if (info.isHidden == null || info.isHidden == false)
        game.log('You have failed a goal: ' + info.name + '.', COLOR_GOAL);

      if (info.messageFailure != null) // failure message
        {
          var img = '';
          if (info.imageFailure != null)
            img = info.imageFailure;
          else img = ('event/' + id + '_failure').toLowerCase();
          game.message(info.messageFailure, img);
        }

      // call failure hook
      if (info.onFailure != null)
        info.onFailure(game, game.player);
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

      throw 'no such goal: ' + id + " " + Std.isOfType(id, String);
    }

}

enum _GoalSilent
{
  SILENT_NONE;
  SILENT_ALL;
  SILENT_SYSTEM;
}
