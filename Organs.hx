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


// passage of time
  public function turn()
    {
      // no organ selected
      if (currentOrgan == null)
        return;

      currentOrgan.gp += 10;
      game.player.energy -= 5;

      // organ not grown yet
      if (currentOrgan.gp < currentOrgan.info.gp)
        return;

      currentOrgan.isReady = true;
      game.log(currentOrgan.info.name + ' growth completed.', Const.COLOR_ORGAN);
      currentOrgan = null;
    }


// player action (called from the gui window))
  public function action(id: String)
    {
      var actionName = id.substr(0, id.indexOf('.'));
      var actionID = id.substr(id.indexOf('.') + 1);

      if (actionName != 'set')
        throw(actionName);

      var imp = game.player.evolutionManager.getImprov(actionID);

      // if this organ does not exist yet, create it
      var o = get(imp.info.organ.id);
      if (o == null)
        {
          currentOrgan = {
            id: imp.info.organ.id,
            isReady: false,
            gp: 0,
            improvInfo: imp.info,
            info: imp.info.organ
            };
          _list.add(currentOrgan);
        }
      else currentOrgan = o;
    }


// has this organ? 
  public function has(id: String): Bool 
    {
      for (o in _list)
        if (o.id == id)
          return true;

      return false;
    }


// get organ by id
  public function get(id: String): Organ
    {
      for (o in _list)
        if (o.id == id)
          return o;

      return null;
    }


// get ready organ by id
  public inline function getReady(id: String): Organ
    {
      var o = get(id);
      return ((o != null && o.isReady) ? o : null);
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
