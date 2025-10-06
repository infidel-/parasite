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
      // lower all main stats to reflect poorer condition
      strength = 2 + Std.random(3);
      constitution = 2 + Std.random(3);
      intellect = 2 + Std.random(3);
      psyche = 2 + Std.random(3);
      // enforce drug addict trait chance for bums
      if (Std.random(100) < 20)
        addTrait(TRAIT_DRUG_ADDICT);
      // increase alcoholic trait chance for bums
      if (Std.random(100) < 20)
        addTrait(TRAIT_ALCOHOLIC);
      derivedStats();
      // prune default belongings to match bum loadout
      inventory.clear();
      skills.clear();
      // allow bums to stumble upon loose change
      if (Std.random(100) < 5)
        inventory.addID('money');
      // give bums occasional cigarettes for flavor
      if (Std.random(100) < 30)
        inventory.addID('cigarettes');
      // stock bums with cheap alcohol for barter
      if (Std.random(100) < 40)
        inventory.addID('alcohol');
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
