// AI for bums

package ai;

import game.Game;

class BumAI extends HumanAI
{
  // creates bum ai with low stats and sparse belongings
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      // prune default belongings to match bum loadout
      inventory.clear();
      skills.clear();
      // allow bums to stumble upon loose change
      if (Std.random(100) < 5)
        inventory.addID('money');
      // give bums occasional cigarettes for flavor
      if (Std.random(100) < 40)
        {
          if (!skills.has(KNOW_SMOKING))
            skills.addID(KNOW_SMOKING);
          inventory.addID('cigarettes');
        }
      initPost(false);
    }

  // sets base attributes and metadata for bum archetype
  public override function init()
    {
      super.init();
      type = 'bum';
      name.unknown = 'bum';
      name.unknownCapped = 'Bum';
      soundsID = 'civilian';
      // lower all main stats to reflect poorer condition
      strength = 2 + Std.random(3);
      constitution = 2 + Std.random(3);
      intellect = 2 + Std.random(3);
      psyche = 2 + Std.random(3);
      derivedStats();
    }

  // handles post-load initialization for bums
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

  // event: handle state changes using human default behavior
  public override function onStateChange()
    {
      onStateChangeDefault();
    }
}
