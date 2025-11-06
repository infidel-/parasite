// NPC AI data
// This separates everything that needs to be stored for proper respawn of this specific AI
package ai;

import const.*;
import ItemInfo.WeaponInfo;
import const.TraitsConst._TraitInfo;
import game.*;

@:rtti
class AIData extends _SaveObject
{
  var game: Game; // game state link

  public var id: Int; // unique AI id
  public static var _maxID: Int = 0; // current max ID
  public var type: String; // ai type
  public var job: String; // ai job
  public var income: Int; // monthly income
  public var eventID: String; // timeline event
  public var npcID: Int;
  public var isNPC: Bool;
  public var tileAtlasX: Int; // tile atlas info
  public var tileAtlasY: Int;
  public var name: _AIName; // AI name (can be unique and capitalized)
  var soundsID: String;

  public var isMale: Bool; // gender
  public var isRelentless: Bool; // will not lose alertness once gained
  public var isAggressive: Bool; // true - attack in alerted state, false - run away
  public var isNameKnown: Bool; // is real name known to player?
  public var isJobKnown: Bool; // is job known to player?
  public var isAttrsKnown: Bool; // are attributes known to player?
  public var isHuman: Bool; // is it a human?
  public var isCommon: Bool; // is it common AI or spawned by area alertness logic?
  public var isTeamMember: Bool; // is this AI a group team member?
  public var isGuard: Bool; // is it a guard? (guards do not despawn when unseen)
  public var hasFalseMemories: Bool; // was this AI given false memories?
  public var affinity: Int; // affinity to parasite (number of turns spent together)
  // cult-related
  public var isCultist: Bool;
  public var cultID: Int;

  // attrs and stats
  public var baseAttrs: _Attributes; // base attributes
  public var modAttrs: _Attributes; // attribute mods
  public var _strength: Int; // current values
  public var _constitution: Int;
  public var _intellect: Int;
  public var _psyche: Int;
  public var strength(get, set): Int; // physical strength (1-10)
  public var constitution(get, set): Int; // physical constitution (1-10)
  public var intellect(get, set): Int; // mental capability (1-10)
  public var psyche(get, set): Int; // mental strength (1-10)
  public var health(default, set): Int; // current health
  public var maxHealth: Int; // maximum health
  public var energy(default, set): Int; // amount of turns until host death
  public var maxEnergy: Int; // max amount of turns until host death
  public var brainProbed: Int; // how many times brain was probed

  public var inventory: Inventory; // AI inventory
  public var skills: Skills; // AI skills
  public var organs: Organs; // AI organs
  public var effects: Effects; // AI effects
  public var traits: List<_AITraitType>;
  public var chat: _AIChat; // chat related vars

  public function new(g: Game)
    {
      id = (_maxID++);
      game = g;
    }

// init object before loading/post creation
  public function init()
    {
      type = 'undefined';
      job = 'undefined';
      income = 0;
      tileAtlasX = -1;
      tileAtlasY = -1;
      name = {
        real: 'undefined',
        realCapped: 'undefined',
        unknown: 'undefined',
        unknownCapped: 'undefined'
      };
      npcID = -1;
      eventID = null;
      isNPC = false;
      chat = {
        needID: 0,
        needStringID: 0,
        aspectID: 0,
        emotionID: EMOTION_NONE,
        emotion: 0,
        eventID: null,
        clues: 0,
        consent: 0,
        stun: 0,
        fatigue: 0,
        timeout: 0,
        turns: 0,
      };
      affinity = 0;
      brainProbed = 0;

      isMale = false;
      isRelentless = false;
      isAggressive = false;
      isCommon = true;
      isNameKnown = false;
      isJobKnown = false;
      isAttrsKnown = false;
      isHuman = false;
      isTeamMember = false;
      hasFalseMemories = false;
      isGuard = false;
      isCultist = false;
      cultID = 0;

      baseAttrs = {
        strength: 1,
        constitution: 1,
        intellect: 1,
        psyche: 1
      };
      modAttrs = {
        strength: 0,
        constitution: 0,
        intellect: 0,
        psyche: 0
      };
      _strength = 0;
      _constitution = 0;
      _intellect = 0;
      _psyche = 0;
      maxHealth = 1;
      health = 1;
      energy = 10;
      maxEnergy = 10;

      inventory = new Inventory(game);
      skills = new Skills(game, false);
      organs = new Organs(game, this);
      effects = new Effects(game, this);
      traits = new List();
    }

// clones this AI data
  public function cloneData(): AIData
    {
      var data = new AIData(game);
      for (f in Type.getInstanceFields(AIData))
        {
          var val = Reflect.field(this, f);
          if (Reflect.isFunction(val)) continue;
          Reflect.setField(data, f, val);
        }
      return data;
    }

// update data in this record from ai
  public function updateData(ai: AIData, src: String)
    {
      game.debug('ai data ' + ai.id + ' updated ' + src);
      for (f in Type.getInstanceFields(AIData))
        {
          var val = Reflect.field(ai, f);
          if (Reflect.isFunction(val)) continue;
          Reflect.setField(this, f, val);
        }
    }

// does this AI have this trait?
  public inline function hasTrait(t: _AITraitType): Bool
    {
      return (Lambda.has(traits, t));
    }

// add trait to this AI
  public function addTrait(t: _AITraitType)
    {
      if (hasTrait(t))
        return;
      traits.add(t);
      var info = TraitsConst.getInfo(t);
      if (info.onInit != null)
        info.onInit(game, this);

      // clamp base just in case (traits could lower that)
      if (baseAttrs.strength < 2)
        baseAttrs.strength = 2;
      if (baseAttrs.constitution < 2)
        baseAttrs.constitution = 2;
      if (baseAttrs.intellect < 2)
        baseAttrs.intellect = 2;
      if (baseAttrs.psyche < 2)
        baseAttrs.psyche = 2;
      // also just in case
      derivedStats();
    }

// add random trait from group
  public function addTraitFromGroup(groupID: String)
    {
      var group = TraitsConst.getGroup(groupID);
      if (group == null || group.length == 0)
        return;
      var candidates: Array<_TraitInfo> = [];
      for (entry in group)
        if (!hasTrait(entry.id))
          candidates.push(entry);
      var pool = candidates.length > 0 ? candidates : group;
      var selection = pool[Std.random(pool.length)];
      addTrait(selection.id);
    }

// recalculate all stat bonuses
  public function recalc()
    {
      // clean mods
      modAttrs.strength = 0;
      modAttrs.constitution = 0;
      modAttrs.intellect = 0;
      modAttrs.psyche = 0;

      // organ: muscle enhancement
      var o = organs.get(IMP_MUSCLE);
      if (o != null)
        modAttrs.strength += o.params.strength;

      _strength = baseAttrs.strength + modAttrs.strength;
      _constitution = baseAttrs.constitution + modAttrs.constitution;
      _intellect = baseAttrs.intellect + modAttrs.intellect;
      _psyche = baseAttrs.psyche + modAttrs.psyche;

      // organ: host energy bonus
      var o = organs.get(IMP_ENERGY);
      var energyMod = 1.0;
      if (o != null)
        energyMod = o.params.hostEnergyMod;

      maxEnergy = Std.int((5 + strength + constitution) * 10 * energyMod);
      maxHealth = strength + constitution;

      // organ: health increase
      var o = organs.get(IMP_HEALTH);
      if (o != null)
        maxHealth += o.params.health;

      // clamp new health if decreased
      health = health;
    }
  
// get current weapon info (returns consts for animals/etc)
  public function getCurrentWeapon(): WeaponInfo
    {
      var item = inventory.getFirstWeapon();
      var info: ItemInfo = null;
      // animal attack
      if (!isHuman)
        info = ItemsConst.getInfo('animal');
      // fists
      else if (item == null)
        info = ItemsConst.getInfo('fists');
      // item
      else info = item.info;
      return info.weapon;
    }

// get name depending on whether its known or not
  public inline function getName(): String
    {
      return (isNameKnown ? name.real : name.unknown);
    }

// get capped name depending on whether its known or not
  public inline function getNameCapped(): String
    {
      return (isNameKnown ? name.realCapped : name.unknownCapped);
    }

// get name + article depending on whether its known or not
  public inline function theName(): String
    {
      return (isNameKnown ? name.real : 'the ' + name.unknown);
    }

// get capped name depending on whether its known or not
  public inline function TheName(): String
    {
      return (isNameKnown ? name.realCapped : 'The ' + name.unknown);
    }

// get capped name depending on whether its known or not
  public inline function AName(): String
    {
      return (isNameKnown ? name.realCapped : 'A ' + name.unknown);
    }

// is this ai a player host?
  public inline function isPlayerHost(): Bool
    {
      return (game.player.state == PLR_STATE_HOST &&
        this.id == game.player.host.id);
    }

// log according to gender
  public function log(s: String, ?col: _TextColor = null)
    {
      if (!isMale)
        {
          s = StringTools.replace(s, 'He ', 'She ');
          s = StringTools.replace(s, ' he ', ' she ');
          s = StringTools.replace(s, ' him', ' her');
          s = StringTools.replace(s, ' his', ' her');
        }
      game.log((isPlayerHost() ? 'Your host' : TheName()) + ' ' + s, col);
    }

// save derived stats (must be called in the end of derived classes constructors)
  public function derivedStats()
    {
      recalc();
      energy = maxEnergy;
      health = maxHealth;
    }

  function set_health(v: Int)
    { return health = Const.clamp(v, 0, maxHealth); }
  function set_energy(v: Int)
    { return energy = Const.clamp(v, 0, maxEnergy); }
  function get_strength()
    { return _strength; }
  function set_strength(v: Int)
    { return baseAttrs.strength = v; }
  function get_constitution()
    { return _constitution; }
  function set_constitution(v: Int)
    { return baseAttrs.constitution = v; }
  function get_intellect()
    { return _intellect; }
  function set_intellect(v: Int)
    { return baseAttrs.intellect = v; }
  function get_psyche()
    { return _psyche; }
  function set_psyche(v: Int)
    { return baseAttrs.psyche = v; }
}
