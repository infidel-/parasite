package particles;

import game.Game;
import haxe.Timer;
import js.html.CanvasRenderingContext2D;

class Particle
{
  var scene: GameScene;
  var game: Game;
  public var createdTS: Float; // in ms
  public var time: Float; // time to live in ms

// weapon shot particle
  public static function createShot(type: String, scene: GameScene, x: Int, y: Int,
      point: _Point, hit: Bool, ?bloodType: String = 'red')
    {
      switch (type)
        {
          case 'attack-pistol':
            new ParticlePistol(scene, x, y,
              point, hit, bloodType);
          case 'attack-assault-rifle':
            new ParticleRifle(scene, x, y,
              point, hit, bloodType);
          case 'attack-shotgun':
            new ParticleShotgun(scene, x, y,
              point, hit, bloodType);
          case 'attack-stun-rifle':
            new ParticleStunRifle(scene, x, y,
              point, hit);
          default:
            trace('no particle for ' + type);
        }
    }

// spit projectile particle
  public static function createSpit(type: String, scene: GameScene, x: Int, y: Int,
      point: _Point)
    {
      switch (type)
        {
          case 'acidSpit', 'slimeSpit', 'paralysisSpit':
            new ParticleSpit(scene, type, x, y, point);
          default:
            trace('no spit particle for ' + type);
        }
    }

// splat particle
  public static function createSplat(type: String, scene: GameScene, pt: _Point,
      ?source: _Point)
    {
      switch (type)
        {
          case 'red', 'black', 'acid', 'slime':
            new ParticleSplat(scene, type, pt, source);
          default:
            trace('unknown splat type ' + type);
            new ParticleSplat(scene, 'red', pt, source);
        }
    }

  public function new(s: GameScene)
    {
      scene = s;
      game = scene.game;
      createdTS = Timer.stamp() * 1000;
      time = 0;
    }

// check if particle is dead
  public function isDead(): Bool
    {
      return (Timer.stamp() * 1000 - createdTS > time);
    }

// base drawing function, should be overridden
  public function draw(ctx: CanvasRenderingContext2D, dt: Float)
    {}

// on death hook
  public function onDeath()
    {}
}
