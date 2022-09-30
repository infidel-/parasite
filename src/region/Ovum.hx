// ovum - marker for rebirth

package region;

import game.Game;
import const.EvolutionConst;

class Ovum extends RegionObject
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'ovum';
      name = 'ovum';
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// update actions
  override function updateActionList()
    {
      game.ui.hud.addAction({
        id: 'setImprovements',
        type: ACTION_OBJECT,
        name: 'Set improvements',
        energy: 0,
        obj: this
      });
      if (game.player.state == PLR_STATE_HOST &&
          game.player.evolutionManager.ovum.level < 5)
        game.ui.hud.addAction({
          id: 'nurtureOvum',
          type: ACTION_OBJECT,
          name: 'Nurture ovum',
          energy: 0,
          obj: this
        });
    }


// activate sewers - leave area
  override function onAction(action: _PlayerAction): Bool
    {
      if (action.id == 'setImprovements')
        {
          game.ui.state = UISTATE_OVUM;
          return true;
        }
      else if (action.id == 'nurtureOvum')
        return nurtureOvumAction(action);

      return true;
    }

// feed the current host to ovum
  function nurtureOvumAction(action: _PlayerAction): Bool
    {
      game.log('You nurture the ovum with the life of your host.');
      var ovum = game.player.evolutionManager.ovum;
      var ovumPoints = [
        'civilian' => 1,
        'scientist' => 2,
        'agent' => 3,
        'security' => 4,
        'team' => 4,
        'police' => 5,
        'soldier' => 10,
        'blackops' => 15,
      ];
      var pts = ovumPoints[game.player.host.type];
      if (pts == null)
        pts = 1;
      ovum.xp += pts;
      game.playerRegion.onHostDeath();

      // new level
      if (ovum.xp <= EvolutionConst.ovumXP[ovum.level])
        return true;
      game.log('The ovum blooms with new power.');
      for (i in 0...(EvolutionConst.ovumXP.length - 1))
        if (ovum.xp > EvolutionConst.ovumXP[i] &&
            ovum.xp <= EvolutionConst.ovumXP[i + 1])
          ovum.level = i + 1;
      return true;
    }

// show additional info
  public override function onMoveTo()
    {
      var ovum = game.player.evolutionManager.ovum;
      var xpInfo = '';
      if (ovum.level < 5)
        xpInfo = ' (' + ovum.xp + '/' + EvolutionConst.ovumXP[ovum.level] + ' pts)';
      var marked = [];
      for (imp in game.player.evolutionManager)
        if (imp.isLocked)
          marked.push(imp.info.name);
      var markedstr = 'No improvements are marked for parthenogenesis.';
      if (marked.length > 0)
        markedstr = 'Marked for parthenogenesis: ' + marked.join(', ') + '.';
      game.log(Const.col('gray', Const.small('[Ovum level ' + ovum.level +
        xpInfo + '. ' + markedstr + ']')));
    }
}
