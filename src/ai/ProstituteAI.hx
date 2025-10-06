// AI for prostitutes

package ai;

import game.Game;

class ProstituteAI extends HumanAI
{
  // creates prostitute ai with social-oriented stats and gear
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      // tailor belongings to match street-working profile
      inventory.clear();
      inventory.addID(Std.random(100) < 55 ? 'smartphone' : 'mobilePhone');
      inventory.addID('money');
      // provide optional self-care utilities
      if (Std.random(100) < 50)
        inventory.addID('contraceptives');
      // give prostitutes a chance to carry cigarettes
      if (Std.random(100) < 50)
        inventory.addID('cigarettes');
      // stash narcotics for transactional leverage
      if (Std.random(100) < 60)
        inventory.addID('narcotics');
      // lean on social manipulation skills
      skills.addID(SKILL_PSYCHOLOGY, 20 + Std.random(20));
      skills.addID(SKILL_COAXING, 30 + Std.random(20));
      skills.addID(SKILL_DECEPTION, 20 + Std.random(20));
      initPost(false);
    }

  // sets base attributes and metadata for prostitute archetype
  public override function init()
    {
      super.init();
      type = 'prostitute';
      name.unknown = 'sex worker';
      name.unknownCapped = 'Sex worker';
      soundsID = 'civilian';
      // bias stats toward social aptitude over physical power
      strength = 3 + Std.random(3);
      constitution = 3 + Std.random(3);
      intellect = 4 + Std.random(3);
      psyche = 4 + Std.random(3);
      // enforce drug addict trait chance for prostitutes
      if (Std.random(100) < 20)
        addTrait(TRAIT_DRUG_ADDICT);
      derivedStats();
    }

  // handles post-load initialization for prostitutes
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
