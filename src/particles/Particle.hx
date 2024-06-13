package particles;

import game.Game;
import js.html.CanvasRenderingContext2D;

class Particle
{
  var scene: GameScene;
  var game: Game;
  public var createdTS: Float; // in ms
  public var time: Float; // time to live in ms

// weapon shot particle
  public static function createShot(type: String, scene: GameScene, x: Int, y: Int, point: _Point, hit: Bool)
    {
      switch (type)
        {
          case 'attack-pistol':
            new ParticlePistol(scene, x, y,
              point, hit);
          case 'attack-assault-rifle':
            new ParticleRifle(scene, x, y,
              point, hit);
          default:
            trace('no particle for ' + type);
        }
    }

  public function new(s: GameScene)
    {
      scene = s;
      game = scene.game;
      createdTS = Sys.time() * 1000;
      time = 0;
    }

// check if particle is dead
  public function isDead(): Bool
    {
      return (Sys.time() * 1000 - createdTS > time);
    }

// base drawing function, should be overridden
  public function draw(ctx: CanvasRenderingContext2D, dt: Float)
    {}

// on death hook
  public function onDeath()
    {}
}
