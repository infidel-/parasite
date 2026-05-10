// rival cult structure
package cult;

import game.Game;

class RivalCult extends Cult
{
  public var rivalTemplate: String;
  public var rivalTactic: _RivalCultTactic;
  public var rivalRevealedLevel: Int;
  public var rivalBaseAreaID: Int;

// create rival cult
  public function new(g: Game)
    {
      super(g);
    }

// init rival cult fields
  public override function init()
    {
      super.init();
      rivalTemplate = '';
      rivalTactic = RIVAL_NON_COMBAT;
      rivalRevealedLevel = 0;
      rivalBaseAreaID = -1;
    }

// called after rival cult load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
      if (rivalTemplate == null)
        rivalTemplate = '';
    }

// run rival cult turn
  public override function turn()
    {
    }
}
