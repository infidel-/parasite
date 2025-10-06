// AI for government agents 

package ai;

import game.Game;

class AgentAI extends HumanAI
{
//  public var isBackup: Bool; // is this AI itself backup?
//  var isBackupCalled: Bool; // did this ai called for backup already?

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      // skill traits for agents
      addTraitFromGroup('skill');
      if (Std.random(100) < 50)
        addTraitFromGroup('skill');
      inventory.addID('pistol');
      skills.addID(SKILL_PISTOL, 40 + Std.random(25));

      skills.addID(SKILL_COMPUTER, 20 + Std.random(20));
      inventory.addID('smartphone');
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'agent';
      name.unknown = 'agent';
      name.unknownCapped = 'Agent';
      soundsID = 'agent';
      isAggressive = true;

//      isBackup = false;
//      isBackupCalled = false;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }
}
