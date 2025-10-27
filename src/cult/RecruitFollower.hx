// recruit follower ordeal - seek the pure
package cult;

import game.Game;
import ai.AIData;
import ai.CorpoAI;

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
      actions = 1;
      note = 'Seek out those who hold sway over ' + followerType + ' matters.';
      // we pick target on creation
      var ai = new CorpoAI(game, 0, 0);
      target = ai.cloneData();
      
      // set ordeal power based on follower type
      switch (followerType)
        {
          case 'combat':
            power.combat = 1;
          case 'media':
            power.media = 1;
          case 'lawfare':
            power.lawfare = 1;
          case 'corporate':
            power.corporate = 1;
          case 'political':
            power.political = 1;
          default:
            power.combat = 1; // default to combat
        }
      power.money = 5000;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
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
