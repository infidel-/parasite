// player state

import entities.PlayerEntity;
import com.haxepunk.HXP;
import ai.AI;
 
class Player
{
  var game: Game; // game state link

  public var evolutionManager: EvolutionManager; // main evolution control

  // knowledge
  public var humanSociety(default, set): Float; // knowledge about human society (0-99.9%)

  // state-independent
  public var energy(default, set): Int; // energy left
  public var maxEnergy: Int; // max energy
  public var health(default, set): Int; // current health
  public var maxHealth: Int; // maximum health
  var knownItems: List<String>; // list of known item types

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
        areaEnergyPerTurn: 10,
        regionMoveEnergy: 15,
        startHealth: 10,
        startEnergy: 100,
        listenRadius: 10,
        losEnabled: true
        };

      state = PLR_STATE_PARASITE;
      energy = vars.startEnergy;
      maxEnergy = vars.startEnergy;
      maxHealth = vars.startHealth;
      health = vars.startHealth;
      hostControl = 0;
      humanSociety = 0.0;
      knownItems = new List<String>();

      skills = new Skills();
    }


// end of turn for player
  public function turn()
    {
      var time = 1;

      // different time speed in region mode
      if (game.location == Game.LOCATION_REGION)
        time = 5;

      // parasite state: decrease energy 
      if (state == PLR_STATE_PARASITE)
        {
          // lose some energy 
          energy -= vars.areaEnergyPerTurn * time;
          if (state == PLR_STATE_PARASITE && energy <= 0)
            {
              game.finish('lose', 'noHost');
              return;
            }
        }

      // host state: decrease host energy
      // host can die, so we need to still check for state later
      if (state == PLR_STATE_HOST)
        {
          host.energy -= time;
          if (host.energy <= 0)
            {
              if (game.location == Game.LOCATION_AREA)
                game.area.player.onHostDeath();
              
              else if (game.location == Game.LOCATION_REGION)
                game.region.player.onHostDeath();

              log('Your host has expired. You have to find a new one.');
            }
        }


      // more host state checks
      if (state == PLR_STATE_HOST)
        {
          // parasite energy restoration
          energy += 10 * time;
          evolutionManager.turn(time);

          host.organs.turn(time); // host organ growth

          // knowledge about human society raises automatically
          // if host memory is available
          if (host.type == 'human' && evolutionManager.getLevel('hostMemory') > 0)
            humanSociety += 0.1 * host.intellect * time;
        }

      // location-specific turn
      if (game.location == Game.LOCATION_AREA)
        game.area.player.turn();
      
      else if (game.location == Game.LOCATION_REGION)
        game.region.player.turn();
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
  public inline function log(s: String, ?col: Int = 0)
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
  function set_humanSociety(v: Float)
    { return humanSociety = Const.clampFloat(v, 0, 99.9); }


// =================================================================================

  public var vars: { // player variables
    areaEnergyPerTurn: Int, // area: energy spent per turn without a host
    regionMoveEnergy: Int, // region: energy cost for movement (+ normal turn cost)
    startHealth: Int, // starting parasite health
    startEnergy: Int, // starting parasite energy
    listenRadius: Int, // player listen radius
    losEnabled: Bool, // LOS checks enabled?
    };


  // base amount of turns the host has to live
//  public static var HOST_EXPIRY_TURNS = 10;

  // base control on invade
  public static var HOST_CONTROL_BASE = 10;
}


// player action type
/*
typedef PlayerAction =
{
  var id: String; // action id
  var name: String; // action name
//  var ap: Int; // action points cost
  var energy: Int; // energy cost
}
*/
