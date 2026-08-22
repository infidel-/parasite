// habitat - biomineral

package objects;

import game.Game;
import lighting.AtmosphereLightProfiles;

class Biomineral extends HabitatObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int, l: Int)
    {
      super(g, vaid, vx, vy, l);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'biomineral formation';
      spawnMessage = 'The biomineral formation is ready to feed the habitat.';
      imageRow = Const.ROW_GROWTH1;
      imageCol = Const.FRAME_BIOMINERAL + level;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// every habitat object shares the 'habitat' type, so the 3D prop lookup keys on this instead
  public override function getModelKey(): String
    { return 'habitat_biomineral'; }

// a grown body is solid: nothing walks through it. this is also what retires the see-through fade
// for this prop — the ghost batch in render.world.ObjModels only ever serves the placement the
// player is STANDING on, and nothing can stand here now
  public override function isWalkable(): Bool
    { return false; }

// the habitat's whole balance sheet, which this organ is the source of. it used to be an onMoveTo
// log line, and blocking the tile above is what took that away — there is no longer any moving onto
// it. the Ctrl-hover tooltip is a better home anyway: these are numbers you check, not an event
  public override function getTooltipRows(): Array<objects.AreaObject.TooltipRow>
    {
      var h = game.area.habitat;
      return [
        {
          name: 'energy',
          value: h.energyUsed + ' / ' + h.energy + ' used',
        },
        {
          name: 'host energy',
          value: '+' + h.hostEnergyRestored + ' / turn',
        },
        {
          name: 'parasite energy',
          value: '+' + h.parasiteEnergyRestored + ' / turn',
        },
        {
          name: 'parasite health',
          value: '+' + h.parasiteHealthRestored + ' / turn',
        },
      ];
    }

// get static atmosphere light emitted by this object
  public override function getAtmosphereLight(): _AtmosphereLightMeta
    {
      return AtmosphereLightProfiles.HABITAT_BIOMINERAL;
    }

// get atmosphere light stamp kind used by this object
  public override function getAtmosphereLightKind(): String
    {
      return 'habitat-biomineral';
    }

/*
// update actions
  override function updateActionList()
    {
      if (game.player.state != PLR_STATE_ATTACHED)
        addAction('enterSewers', 'Enter sewers', 10);
    }


// activate sewers - leave area
  override function onAction(id: String)
    {
      game.log("You enter the damp fetid sewers, escaping the prying eyes.");
      game.turns++; // manually increase number of turns
      game.setLocation(LOCATION_REGION);
    }
*/
}
