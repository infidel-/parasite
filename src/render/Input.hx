package render;

import js.Browser;
import citygen.CityConfig;

// numpad / arrows -> one grid move per keypress (turn-based). Free cam consumes
// the numpad (camera rotation) while active
class Input {
  static final MOVES:Map<String, Array<Int>> = [
    'Numpad8' => [0, -1], 'Numpad2' => [0, 1], 'Numpad4' => [-1, 0], 'Numpad6' => [1, 0],
    'Numpad7' => [-1, -1], 'Numpad9' => [1, -1], 'Numpad1' => [-1, 1], 'Numpad3' => [1, 1],
    'ArrowUp' => [0, -1], 'ArrowDown' => [0, 1], 'ArrowLeft' => [-1, 0], 'ArrowRight' => [1, 0],
  ];

  public static function attach(player:Player, walkable:Array<Array<Bool>>, freeCam:FreeCam):Void {
    Browser.window.addEventListener('keydown', function(e:js.html.KeyboardEvent) {
      if (freeCam != null && freeCam.active) return;
      var delta = MOVES.get(e.code);
      if (delta == null) return;
      e.preventDefault();
      if (player.isMoving) return;

      var col = player.col + delta[0];
      var row = player.row + delta[1];
      if (col < 0 || col >= CityConfig.GRID || row < 0 || row >= CityConfig.GRID) return;
      if (!walkable[row][col]) return;

      player.moveTo(col, row);
    });
  }
}
