// conspiracy group manager

package game;

class Group
{
  var game: Game;

  public var priority(default, set): Float; // group priority (0-100%)

  public function new(g: Game)
    {
      game = g;
      priority = 0;
    }


  function set_priority(v: Float)
    {
      if (v == priority)
        return priority;

      var mod = v - priority;
      priority = Const.clampFloat(v, 0, 100.0);
      game.info('group priority: ' + (mod > 0 ? '+' : '') + mod + ' = ' +
        priority);
      return priority;
    }
}
