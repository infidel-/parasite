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
      type = Entry.AI_BURGLAR;
      isMale = true;
      isAggressive = false;
      soundsID = 'civilian';
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
// onStateChange is a public dynamic event hook on ai.AI — override it directly
  override public function onStateChange(): Void
    {
      if (Std.string(state) != 'AI_STATE_ALERT')
        return;
      vanish();
    }

// gas-poof exit: a 3D paralysis cloud where he stood, the gas sound, then
// removal from the area. removal is deferred a tick so it does not reenter
// the in-progress setState() that triggered this.
// he only ever spawns in AREA_CITY_LOW, which always renders in the 3D street
// view, so there is no 2D particle fallback — playGas no-ops (returns false)
// in the brief window where the view is not running
  function vanish(): Void
    {
      game.scene.city3d.playGas('paralysis', x, y, 1);
      game.scene.sounds.play('action-gas', { x: x, y: y });
      js.Browser.window.setTimeout(function() game.area.removeAI(this), 10);
    }
}
