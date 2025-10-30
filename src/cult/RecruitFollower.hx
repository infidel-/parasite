// recruit follower ordeal - seek the pure
package cult;

import game.Game;
import ai.*;

class RecruitFollower extends Ordeal
{
  public var target: AIData;
  public var followerType: String; // type of power to seek (combat, media, lawfare, corporate, political)

  public function new(g: Game, ?followerType: String = 'combat')
    {
      super(g);
      this.followerType = followerType;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Seek the pure';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 1;
      requiredMemberLevels = 1;
      actions = requiredMembers;
      note = 'Seek out those who hold sway over ' + followerType + ' matters.';
      // we pick target on creation based on follower type
      selectTarget();
      
      // set ordeal power based on follower type
      power.inc(followerType, 1);
      power.money = 5000;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// select target based on follower type
  function selectTarget()
    {
      var ai: ai.AI;
      
      switch (followerType)
        {
          case 'corporate':
            ai = new CorpoAI(game, 0, 0);
            
          case 'combat':
            // random combat type
            var combatTypes: Array<Class<ai.AI>> = [AgentAI, PoliceAI, SecurityAI, SoldierAI, ThugAI];
            var aiClass = combatTypes[Std.random(combatTypes.length)];
            ai = Type.createInstance(aiClass, [game, 0, 0]);
            
          case 'media', 'lawfare', 'political':
            // create civ and then modify with data
            ai = new CivilianAI(game, 0, 0);
            var data = game.scene.images.getFormalCivilianAI(followerType, ai.isMale);
            if (data != null)
              {
                ai.tileAtlasX = data.x;
                ai.tileAtlasY = data.y;
                ai.job = data.job;
                ai.income = data.income;
              }
            
          default:
            // fallback to combat
            ai = new AgentAI(game, 0, 0);
        }
      
      target = ai.cloneData();
    }

// get custom name for display
  public override function customName(): String
    {
      return name + ' - ' + Const.capitalize(followerType);
    }

// handle member death
  public override function onDeath(aidata: AIData)
    {
      fail();
    }

  // handle successful completion
  public override function onSuccess()
    {
      cult.addAIData(target);
    }
}
