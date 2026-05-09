// ai attack target (player, AI, or object)
// helps with stats and events
import ai.AI;
import game.Game;
import objects.AreaObject;

@:structInit
class AITarget
{
  public var game: Game;
  public var type: _AITargetType;
  public var ai: AI;
  public var obj: AreaObject;
  public var x(get, null): Int;
  public var y(get, null): Int;

  public function new(game: Game, type: _AITargetType, ai: AI,
      ?obj: AreaObject)
    {
      this.game = game;
      this.type = type;
      this.ai = ai;
      this.obj = obj;
    }

  function get_x(): Int
    {
      switch (type)
        {
          case TARGET_PLAYER:
            return game.playerArea.x;
          case TARGET_AI:
            return ai.x;
          case TARGET_OBJECT:
            return obj.x;
          default:
            return 0;
        }
    }

  function get_y(): Int
    {
      switch (type)
        {
          case TARGET_PLAYER:
            return game.playerArea.y;
          case TARGET_AI:
            return ai.y;
          case TARGET_OBJECT:
            return obj.y;
          default:
            return 0;
        }
    }

// get name + article depending on whether its known or not
  public function theName(): String
    {
      switch (type)
        {
          case TARGET_PLAYER:
            return 'you';
          case TARGET_AI:
            if (game.player.state == PLR_STATE_HOST &&
                ai == game.player.host)
              return 'your host';
            else return (ai.isNameKnown ? ai.name.real : 'the ' + ai.name.unknown);
          case TARGET_OBJECT:
            return 'the ' + obj.getName();
          default:
            return 'unknown';
        }
    }

// onDamage wrapper
  public function onDamage(damage: Int, ?attacker: AI)
    {
      switch (type)
        {
          case TARGET_PLAYER:
            game.playerArea.onDamage(damage);
          case TARGET_AI:
            if (ai.isPlayerHost())
              game.playerArea.onDamage(damage);
            else ai.onDamage(damage);
          case TARGET_OBJECT:
            obj.onDamage(damage, attacker);
          default:
        }
    }
}
