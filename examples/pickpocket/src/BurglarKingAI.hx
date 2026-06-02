// the Burglar King — a unique, non-hostile street legend. cannot be attached
// to, ignores threats, and if ever forced to alert he vanishes in a gas poof.
// carries a gold-plated cigar and teaches a maxed pickpocket skill via consult.
//
// his defining fields live in init() (which the loader re-runs on the empty
// instance) and his behavior in real override methods (prototype-level), so
// both survive Type.createEmptyInstance reconstruction on save load.
package;

import ai.HumanAI;
import game.Game;

class BurglarKingAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      // the prized cigar plus some pocket money to lift
      inventory.addID(Entry.CIGAR);
      inventory.addID('money');
      // maxed pickpocket so chat consult can teach it
      skills.addID(Entry.SKILL, 99);
      initPost(false);
    }

// identity + flags — also applied on load
  override public function init(): Void
    {
      super.init();
      type = 'burglarKing';
      isMale = true;
      isAggressive = false;
      untyped this.soundsID = 'civilian';
      name.unknown = 'dapper stranger';
      name.unknownCapped = 'Dapper stranger';
      name.real = name.realCapped = 'Burglar King';
    }

// fixed sprite: male atlas row 7, col 1 (a free tile). tileAtlasX/Y are
// serialized, so the icon survives load without re-running this
  override public function createIcon(): Void
    {
      tileAtlasX = 1;
      tileAtlasY = 7;
    }

// the parasite cannot take this host
  override public function canAttach(): Bool
    {
      return false;
    }

// if anything ever drives him to alert, he disappears in a puff of gas.
// not marked override: the engine declares onStateChange as a dynamic hook the
// SDK extern does not surface, so we define it fresh — at JS load it lands on
// our prototype and the engine dispatches into it
  public function onStateChange(): Void
    {
      if (Std.string(state) != 'AI_STATE_ALERT')
        return;
      vanish();
    }

// gas-poof exit: spawn drifting clouds where he stood, play the gas sound,
// then remove him from the area. removal is deferred a tick so it does not
// reenter the in-progress setState() that triggered this. `game` is a live
// engine field not surfaced by the extern — reach it through a cast
  function vanish(): Void
    {
      var g: game.Game = (this : Dynamic).game;
      var scene = g.scene;
      var bx = x;
      var by = y;
      for (i in 0...6)
        new ParticlePoof(scene, bx, by, i);
      scene.sounds.play('action-gas', ({ x: bx, y: by } : _SoundOptions));
      var self = this;
      js.Browser.window.setTimeout(function() g.area.removeAI(self), 10);
    }
}
