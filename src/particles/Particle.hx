package particles;

import game.Game;
import haxe.Timer;
import js.html.CanvasRenderingContext2D;

class Particle
{
  // public so mod-side Particle subclasses inherit a usable scene/game ref
  // through the extern (package-private fields don't make it into externs)
  public var scene: GameScene;
  public var game: Game;
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
      createProjectile(type, scene, x, y, point);
    }

// generic projectile particle
  public static function createProjectile(type: String, scene: GameScene, x: Int,
      y: Int, point: _Point, ?hit: Bool = true, ?bloodType: String = 'red')
    {
      // the 3D view takes over when live (a 2D particle would be hidden under it)
      if (scene.view3d != null &&
          scene.view3d.playProjectile(type, x, y, point.x, point.y, hit, bloodType))
        return;
      switch (type)
        {
          case 'acidSpit', 'slimeSpit', 'paralysisSpit':
            new ParticleSpit(scene, type, x, y, point);
          case 'needle':
            new ParticleNeedle(scene, x, y, point, hit, bloodType);
          default:
            trace('no projectile particle for ' + type);
        }
    }

// splat particle
  public static function createSplat(type: String, scene: GameScene, pt: _Point,
      ?source: _Point)
    {
      // the 3D view takes over when live (a 2D particle would be hidden under it)
      if (scene.view3d != null &&
          scene.view3d.playSplat(type, pt.x, pt.y, source))
        return;
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

// provide optional light pulses for this particle
  public function getLightPulses(): Array<_ParticleLightPulse>
    {
      return [];
    }

// on death hook
  public function onDeath()
    {}
}
