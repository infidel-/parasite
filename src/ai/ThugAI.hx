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
      // toughen physical stats while lowering mental ones
      strength = 6 + Std.random(3);
      constitution = 5 + Std.random(4);
      intellect = 2 + Std.random(3);
      psyche = 3 + Std.random(3);
      // enforce drug addict trait chance for thugs
      if (Std.random(100) < 10)
        addTrait(TRAIT_DRUG_ADDICT);
      derivedStats();
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
      var weaponSkill: _Skill = SKILL_CLUB;
      var weaponBase = 45;
      var weaponSpread = 20;
      var weaponTrait: Null<_AITraitType> = null;
      if (weaponRoll < 5)
        {
          weaponID = 'katana';
          weaponSkill = SKILL_KATANA;
          weaponBase = 55;
          weaponSpread = 20;
          weaponTrait = TRAIT_KENDOKA;
        }
      else if (weaponRoll < 25)
        {
          weaponID = 'pistol';
          weaponSkill = SKILL_PISTOL;
          weaponBase = 40;
          weaponSpread = 20;
          weaponTrait = TRAIT_PISTOL_MARKSMAN;
        }
      else if (weaponRoll < 45)
        {
          weaponID = 'knife';
          weaponSkill = SKILL_KNIFE;
          weaponBase = 35;
          weaponSpread = 15;
          weaponTrait = TRAIT_KNIFE_EXPERT;
        }
      else if (weaponRoll < 65)
        {
          weaponID = 'machete';
          weaponSkill = SKILL_MACHETE;
          weaponBase = 40;
          weaponSpread = 15;
          weaponTrait = TRAIT_GUERRERO;
        }
      else if (weaponRoll < 85)
        {
          weaponID = 'brassKnuckles';
          weaponSkill = SKILL_FISTS;
          weaponBase = 35;
          weaponSpread = 20;
          weaponTrait = TRAIT_BRUISER;
        }
      else
        {
          weaponID = 'baseballBat';
          weaponSkill = SKILL_BATON;
          weaponBase = 45;
          weaponSpread = 15;
          weaponTrait = TRAIT_BATON_EXPERT;
        }
      inventory.addID(weaponID);
      skills.addID(weaponSkill, weaponBase + Std.random(weaponSpread));
      // give thugs a chance to develop weapon specialties
      if (weaponTrait != null && Std.random(100) < 20)
        addTrait(weaponTrait);
      // give thugs a habit-forming vice
      if (Std.random(100) < 30 &&
          !inventory.has('cigarettes'))
        inventory.addID('cigarettes');
      // keep narcotics on hand for street hustle
      if (Std.random(100) < 35)
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
      var jobData = game.jobs.getRandom(type);
      job = jobData.name;
      income = jobData.income;
    }

  // handles post-load initialization for thugs
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

  // turn hook to let thugs target law enforcement
  public override function turn()
    {
      super.turn();

      var seen = game.area.getAIinRadius(x, y, AI.VIEW_DISTANCE, true);
      for (other in seen)
        {
          if (other == this)
            continue;
          if (other.type != 'police' &&
              other.type != 'security')
            continue;
          if (Std.random(100) >= 10)
            continue;
          addEnemy(other);
          // alert this AI (fear/aggro)
          if (state == AI_STATE_IDLE)
            setState(AI_STATE_ALERT);
          emitSound({
            text: 'PIG!',
            radius: 5,
            alertness: 10
          });
        }
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
