// persistent custos AI data
package ai;

import game.Game;

class CustosAIData extends AIData
{
  public var areaID: Int;
  public var x: Int;
  public var y: Int;
  public var anchorX: Int;
  public var anchorY: Int;

  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);
    }

// init custos data fields
  public override function init()
    {
      super.init();
      type = 'firmus';
      isHuman = false;
      isCustos = true;
      isGuard = true;
      isAggressive = true;
      isRelentless = true;
      soundsID = 'dog';
      name = {
        real: 'custos',
        realCapped: 'Custos',
        unknown: 'custos',
        unknownCapped: 'Custos'
      };
      areaID = -1;
      x = 0;
      y = 0;
      anchorX = 0;
      anchorY = 0;
    }

// updates stored custos data from a live AI
  public function updateFromAI(ai: AI, areaID: Int, anchorX: Int,
      anchorY: Int, src: String)
    {
      updateData(ai, src);
      this.areaID = areaID;
      x = ai.x;
      y = ai.y;
      this.anchorX = anchorX;
      this.anchorY = anchorY;
    }

// repairs loaded custos data
  public function initPost(onLoad: Bool)
    {}
}
