// area view glue: every area draws through render.View, so all this keeps is the camera update,
// the 3D path preview feed and the legacy particle list mods still add to

import js.Browser;
import particles.Particle;
import game.Game;

@:expose
class AreaView
{
  var game: Game; // game state link
  var scene: GameScene; // ui scene
  var _particles: List<Particle>;
  var reapIntervalID: Int; // if set, dead particles are reaped every 10 ms

  public function new(s: GameScene)
    {
      scene = s;
      game = scene.game;
      reapIntervalID = 0;
      _particles = new List();
    }

// LEGACY: add a 2D particle. nothing draws it any more; it is kept for mods, and so its onDeath()
// still fires once its time runs out
  public function addParticle(p: Particle)
    {
      _particles.add(p);
      if (reapIntervalID == 0)
        reapIntervalID = Browser.window.setInterval(reapParticles, 10);
    }

// retire dead particles and stop the interval once none are left. the only place onDeath() fires
  function reapParticles()
    {
      for (p in _particles)
        if (p.isDead())
          {
            p.onDeath();
            _particles.remove(p);
          }
      if (_particles.length == 0)
        {
          Browser.window.clearInterval(reapIntervalID);
          reapIntervalID = 0;
        }
    }

// area changed: center the camera on the player (it also sets the gameplay visible rect and kicks
// the 3D view build through GameScene.draw)
  public function update()
    {
      scene.updateCamera();
    }

// clears the path preview
  public function clearPath(?clearAll: Bool = false)
    {
      if (clearAll)
        game.playerArea.clearPath();
      scene.view3d.clearPathPreview();
    }

// feed the 3D view its wavy ribbon path preview: getPath excludes the player's own cell and
// includes the goal, so prepend the player cell for a full player -> target line
  public function updatePath(x1: Int, y1: Int, x2: Int, y2: Int)
    {
      var path = game.area.getPath(x1, y1, x2, y2);
      if (path == null)
        {
          scene.view3d.clearPathPreview();
          return;
        }
      var preview = [ new aPath.Node(x1, y1, 0, null) ];
      for (n in path)
        preview.push(n);
      scene.view3d.setPathPreview(preview);
    }
}
