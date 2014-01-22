// AI organs and other body features like camouflage layers etc

import ConstEvolution;

class Organs
{
  var game: Game;

  var ai: AI; // parent AI link
  var _list: List<Organ>; // list of organs
  var currentOrgan: Organ; // currently grown organ

  public function new(vgame: Game, vai: AI)
    {
      ai = vai;
      game = vgame;
      currentOrgan = null;
      _list = new List<Organ>();
    }


// list iterator
  public function iterator(): Iterator<Organ>
    {
      return _list.iterator();
    }


// player action (called from the gui window))
  public function action(id: String)
    {
      var actionName = id.substr(0, id.indexOf('.'));
      var actionID = id.substr(id.indexOf('.') + 1);

      if (actionName != 'set')
        throw(actionName);

      var imp = game.player.evolutionManager.getImprov(actionID);
//      currentOrgan = imp.or
      trace(imp.info.name);
    }


// add grown organ by id
  public function addID(id: String): Organ
    {
      var impInfo = ConstEvolution.getInfoByOrganID(id);
      if (impInfo == null)
        {
          trace('No such organ: ' + id);
          return null;
        }

      var o = {
        id: id,
        isReady: true,
        gp: 0,
        improvInfo: impInfo,
        info: impInfo.organ
        };

      _list.add(o);
      return o;
    }


  public function toString(): String
    {
      var tmp = [];
      for (o in _list)
        tmp.push(o.id + ' ready:' + o.isReady + ' gp:' + o.gp);
      return tmp.join(', ');
    }


// get currently grown organ info
  public function getGrowInfo(): String
    {
      if (currentOrgan == null)
        return "<font color='#FF0000'>None</font>";
      else return currentOrgan.info.name;
    }
}

typedef Organ =
{
  var id: String; // organ id
  var isReady: Bool; // organ ready?
  var gp: Int; // growth points
  var improvInfo: ImprovInfo; // evolution improvement link
  var info: OrganInfo; // organ info link
}
