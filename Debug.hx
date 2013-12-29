// debug actions

class Debug
{
  var game: Game;

  public function new(g: Game)
    {
      game = g;
    }


// call an action
  public function action(idx: Int)
    {
      var a = actions[idx];
      Reflect.callMethod(this, a.func, []);
    }

// spawn and control host
  function gainHost()
    {
      trace('gain host!');
    }


  public static var actions: Array<{ name: String, func: Dynamic }> = [
    {
      name: 'Gain host',
      func: gainHost
    },
    ];
}
