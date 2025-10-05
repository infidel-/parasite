// AI for street thugs

package ai;

import game.Game;

class ThugAI extends HumanAI
{
  // creates thug ai with aggressive loadout and loot
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      name.real = name.realCapped =
        const.NameConst.getThugName(isMale);
      // rebuild thug inventory with mandated gear
      inventory.clear();
      skills.clear();
      inventory.addID(Std.random(100) < 45 ? 'smartphone' : 'mobilePhone');
      inventory.addID('money');
      // assign a single random weapon loadout
      var weaponRoll = Std.random(100);
      var weaponID = 'baseballBat';
      var weaponSkill: _Skill = SKILL_BATON;
      var weaponBase = 45;
      var weaponSpread = 20;
      if (weaponRoll < 20)
        {
          weaponID = 'pistol';
          weaponSkill = SKILL_PISTOL;
          weaponBase = 40;
          weaponSpread = 20;
        }
      else if (weaponRoll < 40)
        {
          weaponID = 'knife';
          weaponSkill = SKILL_ATTACK;
          weaponBase = 35;
          weaponSpread = 15;
        }
      else if (weaponRoll < 60)
        {
          weaponID = 'machete';
          weaponSkill = SKILL_ATTACK;
          weaponBase = 40;
          weaponSpread = 15;
        }
      else if (weaponRoll < 80)
        {
          weaponID = 'brassKnuckles';
          weaponSkill = SKILL_FISTS;
          weaponBase = 35;
          weaponSpread = 20;
        }
      else
        {
          weaponID = 'baseballBat';
          weaponSkill = SKILL_BATON;
          weaponBase = 45;
          weaponSpread = 15;
        }
      inventory.addID(weaponID);
      skills.addID(weaponSkill, weaponBase + Std.random(weaponSpread));
      // give thugs a habit-forming vice
      if (Std.random(100) < 60 && !inventory.has('cigarettes'))
        inventory.addID('cigarettes');
      // keep narcotics on hand for street hustle
      if (Std.random(100) < 65)
        inventory.addID('narcotics');
      // street experience helps intimidation
      skills.addID(SKILL_PSYCHOLOGY, 20 + Std.random(20));
      skills.addID(SKILL_COERCION, 30 + Std.random(20));
      initPost(false);
    }

  // sets base attributes and metadata for thug archetype
  public override function init()
    {
      super.init();
      type = 'thug';
      name.unknown = 'street thug';
      name.unknownCapped = 'Street thug';
      soundsID = 'thug';
      isAggressive = true;
      // toughen physical stats while lowering mental ones
      strength = 6 + Std.random(3);
      constitution = 5 + Std.random(4);
      intellect = 2 + Std.random(3);
      psyche = 3 + Std.random(3);
      derivedStats();
    }

  // handles post-load initialization for thugs
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// event: on being attacked
  public override function onAttack()
    {
    }

  // event: on state change
  public override function onStateChange()
    {
      // does not need anything from default
    }
}
