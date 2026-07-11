// attack target (player, AI, or object)
// helps with stats and events
import ai.AI;
import entities.Entity;
import game.Game;
import objects.AreaObject;

@:structInit
class AttackTarget
{
  public var game: Game;
  public var type: _AITargetType;
  public var ai: AI;
  public var obj: AreaObject;
  public var x(get, null): Int;
  public var y(get, null): Int;
  public var centerX(get, null): Float;
  public var centerY(get, null): Float;

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

  function get_centerX(): Float
    {
      switch (type)
        {
          case TARGET_PLAYER:
            return game.playerArea.x + 0.5;
          case TARGET_AI:
            return ai.x + 0.5;
          case TARGET_OBJECT:
            return obj.getTargetCenterX();
          default:
            return 0;
        }
    }

  function get_centerY(): Float
    {
      switch (type)
        {
          case TARGET_PLAYER:
            return game.playerArea.y + 0.5;
          case TARGET_AI:
            return ai.y + 0.5;
          case TARGET_OBJECT:
            return obj.getTargetCenterY();
          default:
            return 0;
        }
    }

// returns target's visible world entity for 3D combat effects: an AI's billboard, or the
// player's current body (host or the parasite itself); null for objects
  public function entity(): Entity
    {
      switch (type)
        {
          case TARGET_AI:
            return ai.entity;
          case TARGET_PLAYER:
            return (game.player.state == PLR_STATE_HOST ?
              game.player.host.entity :
              game.playerArea.entity);
          case TARGET_OBJECT:
            return null;
          default:
            return null;
        }
    }

// checks whether target is within melee reach of a tile
  public function isNear(tx: Int, ty: Int): Bool
    {
      return (Math.abs(x - tx) <= 1 && Math.abs(y - ty) <= 1);
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
            return obj.theName();
          default:
            return 'unknown';
        }
    }

// onDamage wrapper
  public function onDamage(damage: Int, ?attacker: Attacker)
    {
      switch (type)
        {
          case TARGET_PLAYER:
            game.playerArea.onDamage(damage);
          case TARGET_AI:
            if (ai.isPlayerHost())
              game.playerArea.onDamage(damage);
            else ai.onDamage(damage, attacker);
          case TARGET_OBJECT:
            // AreaObject.onDamage still uses an AI-typed attacker; pass the
            // wrapper's ai field (null for object attackers)
            obj.onDamage(damage, attacker == null ? null : attacker.ai);
          default:
        }
    }
}
