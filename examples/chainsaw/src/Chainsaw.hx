// chainsaw weapon — extends engine items.Weapon via SDK extern.
// logicAttackPost sprays staggered splats + radial blood spurts around the
// target, fires registered shake + flash fx on player swings, and bumps the
// chainsaw skill on kill. engine constructs this via Type.createInstance, so
// the parasite runtime is reached through Entry.parasite (no ctor threading)
package;

class Chainsaw extends items.Weapon
{
// builds chainsaw weapon info
  public function new(g: game.Game)
    {
      super(g);
      id = 'mod-chainsaw-chainsaw';
      name = 'chainsaw';
      unknown = 'noisy power tool';
      weapon = {
        isRanged: false,
        skill: 'mod-chainsaw-chainsaw-skill',
        minDamage: 4,
        maxDamage: 14,
        verb1: 'rip',
        verb2: 'rips',
        type: WEAPON_MELEE,
        spawnBlood: true,
        canConceal: false,
        // engine AISound is @:structInit but the SDK extern strips that, so
        // mods must construct it explicitly. ctor: (?text, radius, alertness, ?params, ?file)
        sound: new AISound(null, 8, 15, null, 'chainsaw-attack'),
        soundMiss: new AISound(null, 6, 12, null, 'chainsaw-attack-miss'),
      };
    }

// post-hit hook: spray staggered splats around the hit tile + radial blood
// spurts from the target, then if the player swung, fire shake + flash fx
  override public function logicAttackPost(ai: ai.AI,
      target: AttackTarget, isAttackerPlayer: Bool): Void
    {
      // 4 splats staggered over ~280ms so they read as drips rather than a
      // single same-frame pop. capture coords now since closures see them later
      var scene = game.scene;
      var tx = target.x;
      var ty = target.y;
      var sx = ai.x;
      var sy = ai.y;
      for (i in 0...4)
        {
          var delay = 20 + i * 80;
          js.Browser.window.setTimeout(function() {
            var rx = tx + Std.random(3) - 1;
            var ry = ty + Std.random(3) - 1;
            particles.Particle.createSplat('red', scene,
              { x: rx, y: ry },
              { x: sx, y: sy });
          }, delay);
        }

      // 3 blood spurts arc out radially from the target, landing in a red splat.
      // in a 3D area the engine throws them (playProjectile 'blood' lobs the same
      // sine arc and bursts on landing); everywhere else the mod-side 2D particle
      // subclass draws it, since #view covers #canvas and a 2D particle would be
      // hidden under it. same first-refusal shape the engine uses in Particle.hx
      for (i in 0...3)
        {
          var angle = Math.random() * Math.PI * 2;
          var dist = 1 + Std.random(2);
          var landX = tx + Math.round(Math.cos(angle) * dist);
          var landY = ty + Math.round(Math.sin(angle) * dist);
          var delay = i * 70;
          js.Browser.window.setTimeout(function() {
            if (scene.view3d.running)
              scene.view3d.playProjectile('blood', tx, ty, landX, landY, true, 'red');
            else
              new ParticleBloodSpurt(scene,
                { x: tx, y: ty },
                { x: landX, y: landY });
          }, delay);
        }

      if (isAttackerPlayer)
        {
          Entry.parasite.fx.play('mod-chainsaw-shake',
            { durationMS: 500, magnitudePX: 8 });
          Entry.parasite.fx.play('mod-chainsaw-flash',
            { color: 'rgba(255,0,0,1)', alpha: 0.35, durationMS: 500 });
        }

      // attribute kill to chainsaw and bump the chainsaw skill +1% per kill.
      // engine flow: CommonLogic.attack -> target.onDamage -> AI.die() (sets
      // state=DEAD) -> logicAttackPost. so if target.ai.state == DEAD now,
      // this swing is the kill. Skills.increase clamps to 99 so it caps cleanly
      if (isAttackerPlayer &&
          target.ai != null &&
          Std.string(target.ai.state) == 'AI_STATE_DEAD')
        game.player.skills.increase('mod-chainsaw-chainsaw-skill', 1);
    }
}
