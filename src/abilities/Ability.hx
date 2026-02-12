// base class for AI ingrained abilities
package abilities;

import ai.AI;

class Ability extends _SaveObject
{
  public var id: _AbilityType;
  public var name: String;
  public var timeout: Int;

  public function new()
    {
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      name = '';
      timeout = 0;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }

// handles ability logic before normal attack resolution
  public function logicAttack(ai: AI, target: AITarget): Bool
    {
      return false;
    }
}
