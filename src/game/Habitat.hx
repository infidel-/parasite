// habitat-related things

package game;

import objects.*;
import const.*;

class Habitat extends _SaveObject
{
  static var _ignoredFields = [ 'player', 'area',
  ];
  var game: Game;
  var player: Player;
  public var areaID: Int;
  public var area(get, null): AreaGame;

  // calculated stats
  public var energy: Int; // produced energy
  public var energyUsed: Int; // used energy
  public var hostEnergyRestored: Int; // restored energy per turn (host)
  public var parasiteEnergyRestored: Int; // restored energy per turn (parasite)
  public var parasiteHealthRestored: Int; // restored health per turn (parasite)
  public var evolutionBonus: Int; // biomineral evolution bonus (max)
  public var hasWatcher: Bool; // habitat has watcher?
  public var watcherLevel: Int; // habitat watcher level


  public function new(g: Game, a: AreaGame)
    {
      game = g;
      areaID = a.id;
      init();
      initPost();
    }

// init object before loading/post creation
  public function init()
    {
      energy = 0;
      energyUsed = 0;
      hostEnergyRestored = 0;
      parasiteEnergyRestored = 0;
      parasiteHealthRestored = 0;
      evolutionBonus = 0;
      hasWatcher = false;
      watcherLevel = 0;
    }

// called after load or creation
  public function initPost()
    {
      player = game.player;
    }

// put evolution object in habitat
// called from organ actions
  public function putObject(id: _Improv): Bool
    {
      // check for free space
      if (game.area.hasObjectAt(player.host.x, player.host.y))
        {
          game.actionFailed('Not enough free space.');
          return false;
        }

      // check for energy
      if (id != IMP_BIOMINERAL && energyUsed >= energy)
        {
          game.actionFailed('Not enough energy in habitat (' +
            energyUsed + '/' + energy + ').');
          return false;
        }

      // complete goals
      if (id == IMP_BIOMINERAL)
        game.goals.complete(GOAL_PUT_BIOMINERAL);
      if (id == IMP_ASSIMILATION)
        game.goals.complete(GOAL_PUT_ASSIMILATION);
      else if (id == IMP_WATCHER)
        game.goals.complete(GOAL_PUT_WATCHER);

      // spawn object
      var ai = player.host;
      ai.state = AI_STATE_DEAD; // quick kill to fix host discovery
      var level = ai.organs.getLevel(id);
      var o: HabitatObject = null;
      if (id == IMP_BIOMINERAL)
        o = new Biomineral(game, area.id, ai.x, ai.y, level);
      else if (id == IMP_ASSIMILATION)
        o = new AssimilationCavity(game, area.id, ai.x, ai.y, level);
      else if (id == IMP_WATCHER)
        o = new Watcher(game, area.id, ai.x, ai.y, level);
      else if (id == IMP_PRESERVATOR)
        o = new Preservator(game, area.id, ai.x, ai.y, level);

      // remove and kill host
      game.playerArea.onDetach();
      game.area.removeAI(ai);
      // object narrative message
      game.narrative(o.spawnMessage, COLOR_ORGAN);
      // update camera
      game.area.updateVisibility();
      game.scene.updateCamera();
      // update habitat stats
      update();
      game.scene.sounds.play('object-growth');

      return true;
    }


// update habitat stats
  public function update()
    {
      // clear vars
      energy = 0;
      energyUsed = 0;
      hostEnergyRestored = 0;
      parasiteEnergyRestored = 0;
      parasiteHealthRestored = 0;
      evolutionBonus = 0;
      hasWatcher = false;
      watcherLevel = 0;

      // recalc vars
      for (o in area.getObjects())
        // biomineral - give energy
        if (o.name == 'biomineral formation')
          {
            var b: Biomineral = cast o;
            var info = EvolutionConst.getParams(IMP_BIOMINERAL, b.level);
            energy += info.energy;
            if (info.evolutionBonus > evolutionBonus)
              {
                evolutionBonus = info.evolutionBonus;
                hostEnergyRestored = info.hostEnergyRestored;
                parasiteEnergyRestored = info.parasiteEnergyRestored;
                parasiteHealthRestored = info.parasiteHealthRestored;
              }
          }

        // each habitat object uses energy
        else if (o.type == 'habitat')
          {
            var w: Watcher = cast o;
            if (w.name == 'watcher')
              {
                hasWatcher = true;
                if (w.level > watcherLevel)
                  watcherLevel = w.level;
              }

            energyUsed++;
          }

      // no free energy, disable energy and health restoration
      if (energyUsed >= energy)
        {
          hostEnergyRestored = 0;
          parasiteEnergyRestored = 0;
          parasiteHealthRestored = 0;
        }

      Const.debugObject(this);
    }

  function get_area(): AreaGame
    {
      return game.world.get(0).get(areaID);
    }
}
