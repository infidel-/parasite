// the university library's librarian, keeper of the restricted archive
//
// carries an ELDER SIGN (items.ElderSign). While it lives with the sign on it, the sign burns the
// parasite whenever it is within SIGN_RADIUS cells and in sight, bare or through its host
// (game.PlayerArea.onDamage routes it), and the parasite cannot attach to it. Killing it is the way
// past: the sign stays in the body, inert, and cannot be taken.

package ai;

import ai.AI;
import game.Game;

class LibrarianAI extends HumanAI
{
  // the sign's reach in cells, and what it burns each turn
  public static inline var SIGN_RADIUS = 3;
  public static inline var SIGN_DAMAGE = 2;

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      inventory.addID('elderSign');
      skills.addID(SKILL_COMPUTER, 30 + Std.random(20));
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'librarian';
      // the one sprite is an old man (Assets/AI/Library/librarian_male.svg)
      isMale = true;
      name.real = name.realCapped = const.NameConst.getHumanName(isMale);
      name.unknown = N('librarian');
      name.unknownCapped = N('Librarian');
      soundsID = 'civilian';
      var jobData = game.jobs.getRandom(type);
      job = jobData.name;
      income = jobData.income;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// event: on state change
  public override function onStateChange()
    {
      onStateChangeDefault();
    }

// the sign keeps the parasite off
  public override function canAttach(): Bool
    {
      return !inventory.has('elderSign');
    }

// the elder sign burns the parasite in reach and in sight
  public override function turn()
    {
      if (game.area == null ||
          state == AI_STATE_DEAD ||
          !inventory.has('elderSign'))
        return;
      var pa = game.playerArea;
      if (distance(pa.x, pa.y) > SIGN_RADIUS ||
          !seesPosition(pa.x, pa.y))
        return;
      traceAI('LibrarianAI', 'elder sign burns the parasite at ' + pa.x + ',' + pa.y);
      game.log(T('The elder sign the librarian carries sears your mind.'), COLOR_ALERT);
      game.scene.view3d.playSignBurn(game.player.state == PLR_STATE_HOST ?
        game.player.host.entity : pa.entity);
      pa.onDamage(SIGN_DAMAGE);
    }
}
