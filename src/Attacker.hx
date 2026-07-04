// attack source wrapper for AI, player-host, or object attacks
// helps common attack logic use non-AI attackers
import ai.AI;
import game.Game;
import objects.AreaObject;

class Attacker
{
  public var game: Game;
  public var type: _AttackerType;
  public var ai: AI;
  public var obj: AreaObject;
  public var weaponInfo: ItemInfo;
  public var weapon: WeaponInfo;
  public var skillLevel: Float;
  public var alwaysHits: Bool;
  public var isPlayer: Bool;
  public var x(get, null): Int;
  public var y(get, null): Int;
  public var strength(get, null): Int;

// creates an attacker wrapper
  public function new(game: Game, type: _AttackerType, ?ai: AI,
      ?obj: AreaObject, ?weaponInfo: ItemInfo, ?weapon: WeaponInfo,
      ?skillLevel: Float, ?alwaysHits: Bool = false,
      ?isPlayer: Bool = false)
    {
      this.game = game;
      this.type = type;
      this.ai = ai;
      this.obj = obj;
      this.weaponInfo = weaponInfo;
      this.weapon = weapon;
      this.skillLevel = (skillLevel == null ? 0 : skillLevel);
      this.alwaysHits = alwaysHits;
      this.isPlayer = isPlayer;
    }

// creates an attacker wrapper for an AI or player host
  public static function fromAI(game: Game, ai: AI,
      isPlayer: Bool): Attacker
    {
      var weaponInfo = ai.getCurrentWeaponItemInfo();
      return new Attacker(game,
        (isPlayer ? ATTACKER_PLAYER : ATTACKER_AI),
        ai, null, weaponInfo, weaponInfo.weapon,
        ai.skills.getLevel(weaponInfo.weapon.skill), false, isPlayer);
    }

// creates an attacker wrapper for an area object
  public static function fromObject(game: Game, obj: AreaObject,
      weapon: WeaponInfo, skillLevel: Float,
      ?alwaysHits: Bool = false): Attacker
    {
      return new Attacker(game, ATTACKER_OBJECT, null, obj, null, weapon,
        skillLevel, alwaysHits, false);
    }

// returns attacker x coordinate
  function get_x(): Int
    {
      switch (type)
        {
          case ATTACKER_AI, ATTACKER_PLAYER:
            return ai.x;
          case ATTACKER_OBJECT:
            return obj.x;
        }
    }

// returns attacker y coordinate
  function get_y(): Int
    {
      switch (type)
        {
          case ATTACKER_AI, ATTACKER_PLAYER:
            return ai.y;
          case ATTACKER_OBJECT:
            return obj.y;
        }
    }

// returns attacker strength for melee damage bonuses
  function get_strength(): Int
    {
      if (ai == null)
        return 0;
      return ai.strength;
    }

// returns name + article for logs
  public function theName(): String
    {
      switch (type)
        {
          case ATTACKER_PLAYER:
            return 'your host';
          case ATTACKER_AI:
            return ai.theName();
          case ATTACKER_OBJECT:
            return obj.theName();
        }
    }

// returns debug label for attack damage rolls
  public function getDebugName(): String
    {
      switch (type)
        {
          case ATTACKER_PLAYER:
            return 'player';
          case ATTACKER_AI:
            return 'AI';
          case ATTACKER_OBJECT:
            return 'object';
        }
    }

// returns attack event source label
  public function getAttackEventWho(): String
    {
      switch (type)
        {
          case ATTACKER_PLAYER:
            return 'player';
          case ATTACKER_AI:
            return 'ai';
          case ATTACKER_OBJECT:
            return 'object';
        }
    }

// returns true when attacker can use AI-only pre-attack abilities
  public function canUseAttackAbilities(): Bool
    {
      return ai != null && !isPlayer;
    }

// returns true when attacker can move toward a target
  public function canMoveToTarget(): Bool
    {
      return ai != null && !isPlayer;
    }

// returns true when attacker needs ranged line of sight in common logic
  public function needsRangedLineOfSight(): Bool
    {
      return ai != null && !isPlayer;
    }

// checks whether attacker is near a target tile
  public function isNear(tx: Int, ty: Int): Bool
    {
      return (Math.abs(tx - x) <= 1 && Math.abs(ty - y) <= 1);
    }

// checks whether attacker sees a target tile (strict: block sight through wall corners, gun-fire)
  public function seesPosition(tx: Int, ty: Int, ?strict: Bool): Bool
    {
      if (ai != null)
        return ai.seesPosition(tx, ty, strict);
      return game.area.isVisible(x, y, tx, ty, null, strict);
    }

// moves attacker toward a target tile when possible
  public function logicMoveTo(tx: Int, ty: Int)
    {
      if (ai != null)
        ai.logicMoveTo(tx, ty);
    }

// emits attacker sound and alertness
  public function emitSound(sound: AISound, ?playAudio: Bool = true)
    {
      if (ai != null)
        {
          ai.emitSound(sound, playAudio);
          return;
        }

      if (playAudio &&
          sound.file != null)
        game.scene.sounds.play(sound.file, {
          x: x,
          y: y,
          canDelay: true,
          always: (sound.file.indexOf('attack') == 0),
        });
      if (sound.radius <= 0 ||
          sound.alertness <= 0)
        return;

      var list = game.area.getAIinRadius(x, y, sound.radius, false);
      for (other in list)
        if (other.state == AI_STATE_IDLE ||
            other.state == AI_STATE_MOVE_TARGET)
          other.alertness += sound.alertness;
    }

// writes attacker log entry
  public function log(s: String, ?col: _TextColor = null)
    {
      if (ai != null)
        {
          ai.log(s, col);
          return;
        }
      game.log(Const.capitalize(theName()) + ' ' + s, col);
    }

// spends player-host attack energy
  public function spendAttackEnergy()
    {
      if (isPlayer &&
          ai != null)
        ai.energy -= 2;
    }

// returns effect-driven damage modifiers
  public function damageMods(weapon: WeaponInfo): Array<_DamageBonus>
    {
      if (ai == null)
        return [];
      return ai.effects.damageMods(weapon);
    }
}
