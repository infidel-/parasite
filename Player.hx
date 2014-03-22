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

  public var skills: Skills; // skills
  public var state: String; // player state - parasite, attach, host

  // state "host" - store host link here because host exists in all modes
  public var host: AI; // invaded host
  public var hostControl(default, set): Int; // amount of turns until you lose control of the host


  public function new(g: Game)
    {
      game = g;
      evolutionManager = new EvolutionManager(this, game);

      vars = {
        energyPerTurn: 10,
        startHealth: 10,
        startEnergy: 100,
        listenRadius: 10,
        losEnabled: true
        };

      state = STATE_PARASITE;
      energy = vars.startEnergy;
      maxEnergy = vars.startEnergy;
      maxHealth = vars.startHealth;
      health = vars.startHealth;
      hostControl = 0;
      humanSociety = 0.0;

      skills = new Skills();
    }


// end of turn for player
  public function turn()
    {
      // state: parasite
      if (state == STATE_PARASITE)
        {
          // "no host" timer
          energy -= vars.energyPerTurn;
          if (state == STATE_PARASITE && energy <= 0)
            {
              game.finish('lose', 'noHost');
              return;
            }
        }

      // state: host (energy restoration)
      if (state == STATE_HOST)
        {
          energy += 10;
          evolutionManager.turn();
        }

      // state: host (host lifetime timer)
      if (state == STATE_HOST)
        {
          // knowledge about human society raises automatically
          // if host memory is available
          if (host.type == 'human' && evolutionManager.getLevel('hostMemory') > 0)
            humanSociety += 0.1 * host.intellect;
        }

      // location-specific turn
      if (game.location == Game.LOCATION_AREA)
        game.area.player.turn();
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
    energyPerTurn: Int, // energy spent per turn without a host
    startHealth: Int, // starting parasite health
    startEnergy: Int, // starting parasite energy
    listenRadius: Int, // player listen radius
    losEnabled: Bool, // LOS checks enabled?
    };


  // player states
  public static var STATE_PARASITE = 'parasite';
  public static var STATE_ATTACHED = 'attached';
  public static var STATE_HOST = 'host';

  // base amount of turns the host has to live
//  public static var HOST_EXPIRY_TURNS = 10;

  // base control on invade
  public static var HOST_CONTROL_BASE = 10;
}


// player action type

typedef PlayerAction =
{
  var id: String; // action id
  var name: String; // action name
//  var ap: Int; // action points cost
  var energy: Int; // energy cost
}
