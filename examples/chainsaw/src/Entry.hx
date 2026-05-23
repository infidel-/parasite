// chainsaw mod — adds a chainsaw melee weapon + matching skill, juicy hit fx
// (extra blood splats, screen shake, red flash). 30% of spawned thugs get
// a chainsaw instead of their default weapon.
//
// fx are registered against the engine `parasite.fx` facade — the engine owns
// the RAF scheduler, canvas el, and reusable fullscreen overlay div; this mod
// only describes what to draw each frame.
package;

import mods.ModRuntime;

// custom chainsaw weapon. extends engine items.Weapon via SDK extern.
// logicAttackPost sprays extra splats around the target and, if the player
// swung, fires the registered shake + flash fx via parasite.fx.play
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
        skill: cast 'mod-chainsaw-chainsaw-skill',
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

      // 3 blood spurts arc out radially from the target — mod-side particle
      // subclass; landing triggers a red splat at the destination tile
      for (i in 0...3)
        {
          var angle = Math.random() * Math.PI * 2;
          var dist = 1 + Std.random(2);
          var landX = tx + Math.round(Math.cos(angle) * dist);
          var landY = ty + Math.round(Math.sin(angle) * dist);
          var delay = i * 70;
          js.Browser.window.setTimeout(function() {
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
    }
}

@:expose("chainsaw_Entry")
class Entry
{
  // runtime handle saved at init() — Chainsaw.logicAttackPost reaches fx
  // through this since engine constructs Chainsaw via Type.createInstance
  // and does not thread the parasite arg through
  public static var parasite: ModRuntime;

  public static function main() {}

// boot hook — register skill + item, register fx, hook ai:spawn
  public static function init(parasite: ModRuntime): Void
    {
      Entry.parasite = parasite;

      // skill must register before the item — the item's WeaponInfo references it
      parasite.api.registerSkill({
        id: cast 'mod-chainsaw-chainsaw-skill',
        group: 'Combat',
        name: 'chainsaw',
        defaultLevel: 25,
      });
      parasite.api.registerItem(Chainsaw);

      // register shake fx — jitters #canvas via CSS transform, decays to 0.
      // channel = id so a fresh play() interrupts the prior shake instead of
      // running parallel jitters
      parasite.fx.register('mod-chainsaw-shake', {
        play: function(p: Dynamic): Void
          {
            var c: Dynamic = parasite.fx.canvas();
            if (c == null) return;
            var ms: Int = p.durationMS;
            var px: Int = p.magnitudePX;
            parasite.fx.tick(ms, function(t: Float): Void
              {
                var decay = 1 - t;
                var dx = (Math.random() * 2 - 1) * px * decay;
                var dy = (Math.random() * 2 - 1) * px * decay;
                c.style.transform = 'translate(' + dx + 'px,' + dy + 'px)';
              }, function(): Void
              {
                c.style.transform = '';
              }, 'mod-chainsaw-shake');
          },
      });

      // register flash fx — snaps overlay div to color/alpha then transitions
      // opacity to 0. uses the engine's reusable overlay el; engine handles
      // creation, mod handles styling per call
      parasite.fx.register('mod-chainsaw-flash', {
        play: function(p: Dynamic): Void
          {
            var el = parasite.fx.overlay();
            var color: String = p.color;
            var alpha: Float = p.alpha;
            var ms: Int = p.durationMS;
            el.style.background = color;
            el.style.transition = 'none';
            el.style.opacity = '' + alpha;
            // kick the transition on the next frame so the browser registers
            // the opacity delta and animates it instead of snapping
            js.Browser.window.setTimeout(function(): Void
              {
                el.style.transition = 'opacity ' + ms + 'ms ease-out';
                el.style.opacity = '0';
              }, 16);
          },
      });

      // groovie flavor message + sound when the player learns the chainsaw
      parasite.events.onItemLearn(function(e) {
        if (e.item.id != 'mod-chainsaw-chainsaw')
          return;
        e.game.message({
          text: 'Groovie. Aitsu-ra no dare hitori mo yurusenai.',
          img: 'chainsaw-learn',
        });
        e.game.scene.sounds.play('chainsaw-learn');
      });

      // 30% of spawned thugs swap their starter weapon for a chainsaw
      parasite.events.onAISpawn(function(e) {
        if (e.ai.type != 'thug')
          return;
        if (Std.random(100) >= 30)
          return;
        e.ai.inventory.stripAllWeapons();
        e.ai.inventory.addID('mod-chainsaw-chainsaw');
        e.ai.inventory.weaponID = 'mod-chainsaw-chainsaw';
        e.ai.skills.addID(cast 'mod-chainsaw-chainsaw-skill',
          40 + Std.random(20));
      });
    }
}
