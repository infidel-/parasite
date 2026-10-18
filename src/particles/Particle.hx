package particles;

import game.Game;
import haxe.Timer;
import js.html.CanvasRenderingContext2D;

// LEGACY: the 2D particle base. every area renders through render.View, so nothing draws a particle
// any more; the class stays because mods subclass it and add instances through
// AreaView.addParticle, which still fires onDeath() once the time runs out. new effects belong in
// the 3D view (render.View.play*, mods.ModFx). the static helpers below are live: they hand the
// effect to the 3D view and only fall back to the lasting part (sound, persisted splat) when the
// view cannot play it — no shooter actor, or the view still building on area entry
class Particle
{
  // public so mod-side Particle subclasses inherit a usable scene/game ref
  // through the extern (package-private fields don't make it into externs)
  public var scene: GameScene;
  public var game: Game;
  public var createdTS: Float; // in ms
  public var time: Float; // time to live in ms

// weapon shot the 3D view did not play: the impact sound alone (CommonLogic writes the blood)
  public static function createShot(type: String, scene: GameScene, x: Int, y: Int,
      point: _Point, hit: Bool, ?bloodType: String = 'red')
    {
      scene.sounds.play('attack-bullet-' + (hit ? 'hit' : 'miss'), {
        always: true,
        delay: (hit ? 60 : 40),
        x: point.x,
        y: point.y,
      });
    }

// spit projectile
  public static function createSpit(type: String, scene: GameScene, x: Int, y: Int,
      point: _Point)
    {
      createProjectile(type, scene, x, y, point);
    }

// generic projectile; without the 3D flight only the splat it lands is left
  public static function createProjectile(type: String, scene: GameScene, x: Int,
      y: Int, point: _Point, ?hit: Bool = true, ?bloodType: String = 'red')
    {
      if (scene.view3d.playProjectile(type, x, y, point.x, point.y, hit, bloodType))
        return;
      var source = {
        x: x,
        y: y,
      };
      switch (type)
        {
          case 'acidSpit':
            createSplat('acid', scene, point, source);
          case 'slimeSpit':
            createSplat('slime', scene, point, source);
          case 'needle':
            if (hit)
              createSplat(bloodType, scene, point, source);
          default:
        }
    }

// blood splat; without the 3D burst only the persisted decal and the landing sound are left
  public static function createSplat(type: String, scene: GameScene, pt: _Point,
      ?source: _Point)
    {
      if (scene.view3d.playSplat(type, pt.x, pt.y, source))
        return;
      scene.game.area.addSplat(type, pt.x, pt.y);
      scene.sounds.play('fx-splat', {
        x: pt.x,
        y: pt.y,
      });
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

// LEGACY: never called — kept so mod subclasses that override it still compile
  public function draw(ctx: CanvasRenderingContext2D, dt: Float)
    {}

// on death hook
  public function onDeath()
    {}
}
