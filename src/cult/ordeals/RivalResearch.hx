// research a rival cult
package cult.ordeals;

import l10n.Loc;
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
      name = N('Research Rival Cult');
      type = ORDEAL_COMMUNAL;
      requiredMembers = 2;
      actions = requiredMembers;
      rivalCultID = -1;
      note = N('Find names, habits, and finally the rival base.');
    }

// get custom name for display
  public override function customName(): String
    {
      var rival = game.getRivalCultByID(rivalCultID);
      if (rival != null)
        return Loc.tr(name) + ' (' + rival.customName() + ')';
      return Loc.tr(name);
    }

// increases reveal level and creates base area when fully known
  public override function onSuccess()
    {
      var rival = game.getRivalCultByID(rivalCultID);
      if (rival.rivalRevealedLevel >= 2 &&
          rival.rivalBaseAreaID < 0)
        {
          var area = findRivalBaseMarker();
          if (area == null)
            return;
          rival.rivalBaseAreaID = area.id;
        }
      rival.rivalRevealedLevel++;
      cult.log(T('{cult} reveals more about {rival}.', {
        cult: cult,
        rival: Loc.tr(rival.name),
      }));
    }

// finds a city area for the rival base entrance: a quiet one first, then one with events, then any city area
  function findRivalBaseMarker(): AreaGame
    {
      var area = pickRivalBaseMarker(true, true);
      if (area == null)
        area = pickRivalBaseMarker(false, true);
      if (area == null)
        area = pickRivalBaseMarker(false, false);
      return area;
    }

// picks a random city area, with optional event and marker mission filtering; never another rival's base area
  function pickRivalBaseMarker(noEvents: Bool, noMarker: Bool): AreaGame
    {
      var taken = [];
      for (other in game.getRivalCults())
        taken.push(other.rivalBaseAreaID);
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
          if (taken.indexOf(area.id) >= 0)
            continue;
          if (noEvents &&
              area.events.length > 0)
            continue;
          if (noMarker &&
              game.cults[0].ordeals.getMarkerMission(area) != null)
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
            name: T('Research {cult}', { cult: Loc.tr(rival.name) }),
            energy: 0,
            obj: { rivalCultID: rival.id }
          });
        }
    }
}
