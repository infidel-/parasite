// AI for humans (should not be used in the game itself)

package ai;

import game.Game;
import const.ChatConst;
import const.NameConst;

class HumanAI extends AI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
// will be called by sub-classes
//      init();
//      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'human';
      isMale = (Std.random(100) < 50 ? true : false);
      name.real = name.realCapped =
        const.NameConst.getHumanName(isMale);

      isHuman = true;
      strength = 4 + Std.random(4);
      constitution = 4 + Std.random(4);
      intellect = 4 + Std.random(4);
      psyche = 4 + Std.random(4);
      // chat-related
      chat.needID = Std.random(
        ChatConst.needs.length);
      chat.needStringID = Std.random(
        ChatConst.needStrings[chat.needID].length);
      chat.consent = 10;
      if (Std.random(100) < 70) // 30% normal
        chat.aspectID = Std.random(
          ChatConst.aspects.length);

      // MATH: health 8-16 (~12), energy 130-210 (~170)

      // common skills for all humans
      if (Std.random(100) < 10)
        {
          skills.addID(KNOW_SMOKING);
          inventory.addID('cigarettes');
        }
      if (Std.random(100) < 75)
        {
          skills.addID(KNOW_SHOPPING);
          inventory.addID(Std.random(10) < 7 ? 'wallet' : 'money');
        }
      // chat-related
      if (Std.random(100) < 30)
        skills.addID(SKILL_PSYCHOLOGY, 10 + Std.random(5));
      var rnd = Std.random(100);
      if (rnd < 30)
        skills.addID(SKILL_DECEPTION, 10 + Std.random(10));
      else if (rnd < 70)
        skills.addID(SKILL_COERCION, 10 + Std.random(10));
      else if (rnd < 100)
        skills.addID(SKILL_COAXING, 10 + Std.random(10));
      // items
      if (Std.random(100) < 10)
        inventory.addID('sleepingPills');
      if (Std.random(100) < 10)
        inventory.addID('contraceptives');

      // common traits for all humans
      if (Std.random(100) < 10)
        addTrait(TRAIT_DRUG_ADDICT);

      derivedStats();
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }


// event: despawn live AI
  public override function onRemove()
    {
      // do previous host consequences
      if (wasInvaded || wasAttached)
        game.managerRegion.onHostDiscovered(game.area, this);
    }
}

