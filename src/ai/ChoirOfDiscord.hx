// summoned monster AI: choir of discord

package ai;

import game.Game;

class ChoirOfDiscord extends AI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      abilities.addID(ABILITY_CHOIR_SILENT_SCREAM);
      abilities.addID(ABILITY_CHOIR_MELEE);
      game.goals.aiInit(this);
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'choirOfDiscord';
      name.real = 'choir of discord';
      name.realCapped = 'Choir of discord';
      name.unknown = 'choir of discord';
      name.unknownCapped = 'Choir of discord';
      isNameKnown = true;
      isJobKnown = true;
      soundsID = 'choir';
      isHuman = false;
      isMale = true;
      isAggressive = true;
      isRelentless = true;
      helpAvailable = false;

      strength = 9;
      constitution = 10;
      intellect = 2;
      psyche = 9;
      derivedStats();
      energy = 999;
      maxEnergy = 999;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// check if this AI should use "it" pronouns
  public override function isIt(): Bool
    {
      return true;
    }

// cannot be attached by parasite
  public override function canAttach(): Bool
    {
      return false;
    }

// returns black blood splats for choir
  public override function bloodType(): String
    {
      return 'black';
    }

// acquire all visible targets each turn and stay aggressive
  public override function turn()
    {
      if (game.area == null ||
          state == AI_STATE_DEAD)
        return;

      // loop through visible AIs and add as enemies
      var hasTargets = false;
      var seen = game.area.getAIinRadius(x, y, AI.VIEW_DISTANCE, true);
      for (other in seen)
        {
          if (other == this ||
              other.state == AI_STATE_DEAD)
            continue;
          addEnemy(other);
          hasTargets = true;
        }

      // check for player if not invisible
      if (!game.player.vars.invisibilityEnabled &&
          seesPosition(game.playerArea.x, game.playerArea.y))
        hasTargets = true;

      // alert if acquired any targets
      if (hasTargets &&
          state != AI_STATE_ALERT)
        setState(AI_STATE_ALERT, REASON_WITNESS);
    }
}
