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
      // rebuild thug inventory with mandated gear
      inventory.clear();
      skills.clear();
      inventory.addID(Std.random(100) < 45 ? 'smartphone' : 'mobilePhone');
      inventory.addID('money');
      // equip thugs with a mostly guaranteed weapon
      var roll = Std.random(100);
      if (roll < 60)
        {
          inventory.addID('baton');
          skills.addID(SKILL_BATON, 45 + Std.random(20));
        }
      else
        {
          inventory.addID('pistol');
          skills.addID(SKILL_PISTOL, 40 + Std.random(20));
        }
      // ensure a fallback weapon exists if RNG failed
      if (inventory.getFirstWeapon() == null)
        {
          inventory.addID('baton');
          skills.addID(SKILL_BATON, 35 + Std.random(15));
        }
      // give thugs a habit-forming vice
      if (Std.random(100) < 60)
        {
          if (!skills.has(KNOW_SMOKING))
            skills.addID(KNOW_SMOKING);
          if (!inventory.has('cigarettes'))
            inventory.addID('cigarettes');
        }
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
