// player/AI abilities
package ai;

import abilities.*;

class Abilities extends _SaveObject
{
  var list: Array<Ability>;

  public function new()
    {
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      list = [];
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }

// list iterator
  public function iterator(): Iterator<Ability>
    {
      return list.iterator();
    }

// checks if ability list has this id
  public function has(id: _AbilityType): Bool
    {
      for (ability in list)
        if (ability.id == id)
          return true;
      return false;
    }

// adds ability by id if it is not present
  public function addID(id: _AbilityType)
    {
      if (has(id))
        return;

      switch (id)
        {
          case ABILITY_DEADLY_CARESS:
            list.push(new DeadlyCaress());
        }
    }
}
