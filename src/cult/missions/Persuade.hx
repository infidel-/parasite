package cult.missions;

import game.Game;
import ai.*;

class Persuade extends Mission
{
  public var target: AIData;

  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);
    }

  // init object before loading/post creation
  public override function init()
    {
      super.init();
      type = MISSION_PERSUADE;
      name = 'Persuade Target';
      note = 'A specific target must be persuaded to join your cause.';

      // create random civilian AI and clone its data
      var ai = new CivilianAI(game, 0, 0);
      target = ai.cloneData();
      target.isNameKnown = true;
      // pick random area position
      var area = game.region.getRandom({
        noMission: true,
        noEvents: true,
        type: AREA_CITY_HIGH
      });
      if (area != null)
        {
          x = area.x;
          y = area.y;
        }
    }

  // turn hook for persuade mission
  public override function turn()
    {
      if (game.location != LOCATION_AREA) return;
      if (game.area == null) return;
      if (game.area.x != x || game.area.y != y)
        return;

      // return if target already spawned
      var targetAI = game.area.getAIByID(target.id);
      if (targetAI != null) return;

      // return if cannot find spawn location
      var loc = game.area.findUnseenEmptyLocation();
      if (loc.x < 0)
        loc = game.area.findEmptyLocationNear(
          game.playerArea.x, game.playerArea.y, 5);
      if (loc == null) return;

      // spawn target AI
      var ai = game.area.spawnAI(target.type, loc.x, loc.y, false);
      ai.updateData(target, 'on spawn');
      game.area.addAI(ai);
      ai.entity.setMissionTarget();
      game.debug('Target ' + target.TheName() + ' has appeared.');
    }

  // get custom name for display
  public override function customName(): String
    {
      if (target != null)
        return name + ' - ' + target.TheName();
      return name;
    }

  // handle AI events
  public override function onEventAI(type: _MissionEvent, ai: AI)
    {
      // check if the event is about the target
      if (ai.id != target.id)
        return;

      switch (type)
        {
          case ON_AI_DEATH:
            fail(); // fail the mission if target dies
          case ON_AI_MAX_CONSENT:
            success(); // complete the mission if target reaches max consent
        }
    }
}
