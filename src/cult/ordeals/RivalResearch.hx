// research a rival cult
package cult.ordeals;

import cult.Cult;
import cult.Ordeal;
import game.AreaGame;
import _PlayerAction;

class RivalResearch extends Ordeal
{
  public var rivalCultID: Int;

  public function new(g: game.Game, rivalCultID: Int)
    {
      super(g);
      init();
      this.rivalCultID = rivalCultID;
      initPost(false);
      addRandomMembers({
        level: 1,
        amount: 2,
      });

      // pick 2 random power types (including money)
      var allTypes = ['media', 'lawfare', 'corporate', 'political', 'money'];
      var shuffled = [];
      for (t in allTypes)
        shuffled.push(t);
      shuffled.sort(function(a, b) return Std.random(3) - 1);
      var type = shuffled[0];
      if (type == 'money')
        power.money = 40000;
      else
        power.inc(type, 2);
    }

// init ordeal fields
  public override function init()
    {
      super.init();
      name = 'Research Rival Cult';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 2;
      actions = requiredMembers;
      rivalCultID = -1;
      note = 'Find names, habits, and finally the rival base.';
    }

// get custom name for display
  public override function customName(): String
    {
      var rival = game.getRivalCultByID(rivalCultID);
      if (rival != null)
        return name + ' (' + rival.customName() + ')';
      return name;
    }

// increases reveal level and creates base area when fully known
  public override function onSuccess()
    {
      var rival = game.getRivalCultByID(rivalCultID);
      rival.rivalRevealedLevel++;
      if (rival.rivalRevealedLevel >= 3 &&
          rival.rivalBaseAreaID < 0)
        {
          var area = findRivalBaseMarker();
          if (area == null)
            return;
          rival.rivalBaseAreaID = area.id;
        }
      cult.log('reveals more about ' + rival.name);
    }

// finds a city marker area for the rival base entrance
  function findRivalBaseMarker(): AreaGame
    {
      var area = pickRivalBaseMarker(true);
      if (area != null)
        return area;
      return pickRivalBaseMarker(false);
    }

// picks a random city marker area with optional event filtering
  function pickRivalBaseMarker(noEvents: Bool): AreaGame
    {
      var candidates = [];
      for (area in game.region)
        {
          if (area.x < 0 ||
              area.y < 0)
            continue;
          if (area.typeID != AREA_CITY_LOW &&
              area.typeID != AREA_CITY_MEDIUM &&
              area.typeID != AREA_CITY_HIGH)
            continue;
          if (noEvents &&
              area.events.length > 0)
            continue;
          if (game.cults[0].ordeals.getMarkerMission(area) != null)
            continue;
          candidates.push(area);
        }
      if (candidates.length == 0)
        return null;
      return candidates[Std.random(candidates.length)];
    }

// adds one research action per active hidden rival
  public static function initiateAction(cult: Cult, actions: Array<_PlayerAction>)
    {
      for (rival in cult.game.getRivalCults(true))
        {
          if (rival.rivalRevealedLevel >= 3)
            continue;
          actions.push({
            id: 'rivalResearch',
            type: ACTION_CULT,
            name: 'Research ' + rival.name,
            energy: 0,
            obj: { rivalCultID: rival.id }
          });
        }
    }
}
