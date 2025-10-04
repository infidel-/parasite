// AI for humans (should not be used in the game itself)

package ai;

import game.Game;
import const.ChatConst;

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
        inventory.addID('cigarettes');
      if (Std.random(100) < 75)
        inventory.addID(Std.random(10) < 7 ? 'wallet' : 'money');
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
      // agreeable hosts will not be discovered
      if ((wasInvaded || wasAttached) && !isAgreeable())
        game.managerRegion.onHostDiscovered(game.area, this);
    }

// event: default on state change for any civs (scientists, office workers, etc)
  function onStateChangeDefault()
    {
      // try to call police on next turn if not struggling with parasite
      // if berserk, just skip that
      // same with if player cultist
      if (state == AI_STATE_ALERT &&
          !parasiteAttached &&
          !effects.has(EFFECT_BERSERK) &&
          !isPlayerCultist())
        {
          // cannot call police without a phone
          if (!inventory.has('smartphone') &&
              !inventory.has('mobilePhone'))
            return;

          // no reception in habitat
          if (game.area.isHabitat)
            {
              log('fumbles with something in its hands. "Shit! No reception!"');

              return;
            }

          var time = 1;
          if (game.player.difficulty == UNSET ||
              game.player.difficulty == EASY)
            time = 2;
          game.managerArea.addAI(this, AREAEVENT_CALL_LAW, time);
        }
    }
}
