// player state

package game;

import entities.PlayerEntity;
import ai.AI;

class Player
{
  var game: Game; // game state link

  public var evolutionManager: EvolutionManager; // main evolution control

  // state-independent
  public var energy(default, set): Int; // energy left
  public var maxEnergy: Int; // max energy
  public var health(default, set): Int; // current health
  public var maxHealth: Int; // maximum health
  var knownItems: List<String>; // list of known item types

  public var vars: PlayerVars; // player variables
  public var skills: Skills; // skills
  public var state: _PlayerState; // player state - parasite, attach, host

  // state "host" - store host link here because host exists in all modes
  public var host: AI; // invaded host
  public var hostControl(default, set): Int; // amount of turns until you lose control of the host


  public function new(g: Game)
    {
      game = g;
      evolutionManager = new EvolutionManager(this, game);

      vars = {
        inventoryEnabled: false,
        skillsEnabled: false,
        timelineEnabled: false,
        organsEnabled: false,
        npcEnabled: false,
        searchEnabled: false,

        evolutionEnergyPerTurn: 5,
        evolutionEnergyPerTurnMicrohabitat: 4,
        organGrowthEnergyPerTurn: 5,
        organGrowthPointsPerTurn: 10,

        areaEnergyPerTurn: 5,
        regionEnergyPerTurn: 15,
        startHealth: 10,
        startEnergy: 50,
        maxEnergy: 100,
        listenRadius: 10,
        losEnabled: true,
        invisibilityEnabled: false,
        godmodeEnabled: true,
        };

      state = PLR_STATE_PARASITE;
      energy = vars.startEnergy;
      maxEnergy = vars.maxEnergy;
      maxHealth = vars.startHealth;
      health = vars.startHealth;
      hostControl = 0;
      knownItems = new List<String>();

      skills = new Skills(game, true);
    }


// end of turn for player
  public function turn()
    {
      var time = 1;

      // different time speed in region mode
      if (game.location == LOCATION_REGION)
        time = 5;

      // parasite state: energy and health
      if (state == PLR_STATE_PARASITE)
        {
          var delta = __Math.parasiteEnergyPerTurn(time);
          // DEBUG: godmode
          if (!vars.godmodeEnabled)
            energy += delta;

          if (state == PLR_STATE_PARASITE && energy <= 0)
            {
              game.finish('lose', 'noHost');
              return;
            }
        }

      // all states: restore health in habitat
      if (game.location == LOCATION_AREA && game.area.isHabitat)
        health += game.area.habitat.parasiteHealthRestored * time;

      // host state: host energy
      // host can die, so we still need to check for state later
      if (state == PLR_STATE_HOST)
        {
          var delta = __Math.hostEnergyPerTurn(time);
          host.energy += delta;

          if (host.energy <= 0)
            onHostDeath('Your host has expired. You have to find a new one.');
        }

      // more host state checks
      // we check for the 2nd time, because host could die in previous block
      if (state == PLR_STATE_HOST)
        {
          // parasite energy restoration
          var delta = __Math.parasiteEnergyPerTurn(time);
          energy += delta;

          host.organs.turn(time); // host organ growth

          // knowledge about human society raises automatically
          // if host memory is available
          if (host.type == 'human' &&
              evolutionManager.getLevel(IMP_BRAIN_PROBE) > 0)
            skills.increase(KNOW_SOCIETY, 0.1 * host.intellect * time);

          // evolution can kill host (change state)
          evolutionManager.turn(time);
        }

      // location-specific turn
      if (game.location == LOCATION_AREA)
        game.playerArea.turn();

      else if (game.location == LOCATION_REGION)
        game.playerRegion.turn();
    }


// convenience method for host death
  public inline function onHostDeath(msg: String)
    {
      if (game.location == LOCATION_AREA)
        game.playerArea.onHostDeath();

      else if (game.location == LOCATION_REGION)
        game.playerRegion.onHostDeath();

      log(msg);
    }


// add item to known list
  public inline function addKnownItem(id: String)
    {
      return knownItems.add(id);
    }


// does player know about this item?
  public inline function knowsItem(id: String): Bool
    {
      return (Lambda.has(knownItems, id));
    }


// =================================================================================


// log
  public inline function log(s: String, ?col: _TextColor)
    {
      game.log(s, col);
    }


// =================================  SETTERS  ====================================
  function set_energy(v: Int)
    { return energy = Const.clamp(v, 0, maxEnergy); }
  function set_health(v: Int)
    { return health = Const.clamp(v, 0, maxHealth); }
  function set_hostControl(v: Int)
    { return hostControl = Const.clamp(v, 0, 100); }


// =================================================================================


  // base amount of turns the host has to live
//  public static var HOST_EXPIRY_TURNS = 10;

  // base control on invade
  public static var HOST_CONTROL_BASE = 10;
}


// player variables typedef

private typedef PlayerVars = {
  // game flags and vars

  // GUI and initial progression flags (set on goal completion)
  inventoryEnabled: Bool,
  skillsEnabled: Bool,
  timelineEnabled: Bool,
  organsEnabled: Bool,
  npcEnabled: Bool, // npc spawn enabled?
  searchEnabled: Bool, // computer search info enabled?

  evolutionEnergyPerTurn: Int, // energy spent per turn during evolution
  evolutionEnergyPerTurnMicrohabitat: Int, // -- in microhabitat
  organGrowthEnergyPerTurn: Int, // energy spent per turn when growing organs
  organGrowthPointsPerTurn: Int, // organ growth points per turn

  areaEnergyPerTurn: Int, // area: energy spent per turn without a host
  regionEnergyPerTurn: Int, // region: energy cost per turn without a host
  startHealth: Int, // starting parasite health
  startEnergy: Int, // starting parasite energy
  maxEnergy: Int, // max parasite energy
  listenRadius: Int, // player listen radius
  losEnabled: Bool, // LOS checks enabled?
  invisibilityEnabled: Bool, // player invisibility enabled?
  godmodeEnabled: Bool, // player godmode enabled?
  };
