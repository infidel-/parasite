// chainsaw mod — adds a chainsaw melee weapon + matching skill, juicy hit fx
// (extra blood splats, screen shake, red flash, split-icon body halves).
// 30% of spawned thugs get a chainsaw instead of their default weapon.
//
// fx are registered against the engine `parasite.fx` facade — the engine owns
// the RAF scheduler, canvas el, and reusable fullscreen overlay div; this mod
// only describes what to draw each frame.
//
// the Chainsaw weapon class lives in Chainsaw.hx; this file wires registration
// and the engine event hooks the mod subscribes to
package;

import mods.ModRuntime;

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
        id: 'mod-chainsaw-chainsaw-skill',
        group: 'Combat',
        name: 'chainsaw',
        defaultLevel: 25,
      });
      parasite.api.registerItem(Chainsaw);

      // register "everyone must pay" goal — granted on chainsaw learn.
      // noteFunc renders the running kill count read from per-savegame data
      parasite.api.registerGoal({
        id: 'mod-chainsaw-everyone-must-pay',
        name: 'Minna mukui o ukete morau',
        note: Const.col('red', 'Make them all bleed.'),
        noteFunc: function(g) {
          var n = parasite.savedata.getInt('kills', 0);
          return 'Deaths so far: ' + n + '.';
        },
        messageReceive: 'Time to settle the score.',
      });

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

      // flavor message + sound when the player learns the chainsaw.
      // also grants the "everyone must pay" goal — gated on learn so the goal
      // only enters the journal once the player actually acquires the weapon
      parasite.events.onItemLearn(function(e) {
        if (e.item.id != 'mod-chainsaw-chainsaw')
          return;
        e.game.message({
          text: 'Gurubie. Aitsu-ra no dare hitori mo yurusenai.',
          img: 'chainsaw-learn',
        });
        e.game.scene.sounds.play('chainsaw-learn');
        e.game.goals.receive('mod-chainsaw-everyone-must-pay');
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
        e.ai.skills.addID('mod-chainsaw-chainsaw-skill',
          40 + Std.random(20));
      });

      // split-icon kill effect: on player chainsaw kills, slice the target
      // sprite in two unevenly, fling halves to nearby tiles, hold briefly,
      // then fade. uses ai:die-pre because ai.entity is still live there;
      // by the time ai:die fires AreaGame.removeAI has already nulled it
      parasite.events.onAIDiePre(function(e) {
        if (e.attacker == null)
          return;
        if (!e.attacker.isPlayer)
          return;
        if (e.attacker.weaponInfo == null ||
            e.attacker.weaponInfo.id != 'mod-chainsaw-chainsaw')
          return;
        if (e.entity == null)
          return;
        var pos: _Point = { x: e.ai.x, y: e.ai.y };
        // random cut: angle in [0, π) covers all unique lines; pivot near
        // tile center so both halves stay roughly non-degenerate in area
        var tile = Const.TILE_SIZE;
        var cutAngle = Math.random() * Math.PI;
        var cutX = tile * (0.35 + Math.random() * 0.30);
        var cutY = tile * (0.35 + Math.random() * 0.30);
        new ParticleSplitIconHalf(e.game.scene, pos, e.entity,
          cutAngle, cutX, cutY, 0);
        new ParticleSplitIconHalf(e.game.scene, pos, e.entity,
          cutAngle, cutX, cutY, 1);
      });

      // kill counter — once the player has the goal, every AI death in the
      // current area counts. stored per-savegame so reloading a slot rewinds
      // the tally to the saved point. when the count reaches 99, fire the
      // win finish screen directly (no goal completion — finish screen alone)
      parasite.events.onAIDie(function(e) {
        if (!e.game.goals.has('mod-chainsaw-everyone-must-pay'))
          return;
        var n = parasite.savedata.getInt('kills', 0) + 1;
        parasite.savedata.set('kills', n);
        if (n >= 99)
          e.game.finish({
            result: 'win',
            text: Const.col('red', '<i>Subete no mono o yurushita.</i>'),
            img: 'chainsaw-win',
          });
      });

      // game-over override: replace the engine death text + image with a
      // chainsaw-flavored sendoff showing how many fell. fires on any 'lose'
      // result, regardless of the underlying death cause (noHost, noEnergy, …)
      parasite.events.onGameFinishPre(function(e) {
        if (e.result != 'lose')
          return;
        if (!e.game.goals.has('mod-chainsaw-everyone-must-pay') &&
            !e.game.goals.completed('mod-chainsaw-everyone-must-pay'))
          return;
        var kills = parasite.savedata.getInt('kills', 0);
        e.text = 'You took ' + Const.col('gray', kills) +
          ' with you on the way out.<br>' +
          Const.col('red', '<i>Mou, minna yurushita.</i>');
        e.img = 'chainsaw-lose';
      });
    }
}
