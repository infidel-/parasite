// Metamorphosis Phase II communal ordeal: a three-stage ritual pinned to the habitat it began in, each
// stage channelled from the cult window, played round the player (render.particles.RitualFx3D) and
// closed by a vision; the third grows the base
package cult.ordeals;

import l10n.Loc;
import cult.Cult;
import cult.Ordeal;
import cult.RivalCult;
import const.CultBaseConst;
import cult.base.CultBase;
import game.Game;
import ui.Choice._ChoiceParams;
import _PlayerAction;
import _PlayerActionType;

class MetamorphosisPhaseII extends Ordeal
{
  static var _ignoredFields = [ 'cult', 'channelling' ];
  public static inline var STAGES = 3;
  static inline var HEART_SEARCH = 6;   // cells round the player searched for room for the heart
  // one vision per stage: a rival cult, the Corpus Basilica, the Heart's birth
  static var visions = [
    {
      title: N('Other Altars'),
      text: N('The flesh opens an eye that is not yours. Across the city, masked strangers kneel in a ring of cold light and sing to a god that is not the Heart. They do not see you yet. They will.'),
      img: 'img/cult/vision-rival.jpg',
    },
    {
      title: N('Corpus Basilica'),
      text: N('The walls of the lair rise into ribbed vaults and veined windows, a cathedral grown from meat and bone. A vast heart hangs where an altar should be, and the faithful stand beneath it in their thousands. This is what the flesh can become.'),
      img: 'img/cult/vision-basilica.jpg',
    },
    {
      title: N('Cor Nefandum'),
      text: N('The floor splits. Something red and furious drags itself up out of the old growths, beating, burning from inside. Your followers fall to their knees. The Forbidden Heart is born, and it knows its name.'),
      img: 'img/cult/vision-heart.jpg',
    },
  ];
  public var areaID: Int; // the habitat the ritual is pinned to (-1 = not yet, pinned on the first stage)
  public var stage: Int; // stages channelled, 0..STAGES
  var channelling: Bool; // a stage's animation is playing (not saved: a save mid-animation drops the stage)

  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);
      var free = cult.getFreeMembers(3, true);
      if (free.length > 0)
        addMembers([ free[0] ]);
      if (game.location == LOCATION_AREA &&
          game.area.isHabitat)
        areaID = game.area.id;
    }

// init ordeal fields
  public override function init()
    {
      super.init();
      name = N('Metamorphosis, Phase II');
      type = ORDEAL_COMMUNAL;
      requiredMembers = 1;
      requiredMemberLevels = 3;
      actions = 0;
      note = N('Channel the ritual in the habitat where it began.');
      areaID = -1;
      stage = 0;
      channelling = false;
    }

// the note with the stage reached
  public override function getNote(): String
    {
      return T('Channel the ritual in the habitat where it began. Stage {stage}/{stages}.', {
        stage: stage,
        stages: STAGES,
      });
    }

// adds the channel action for the next stage
  public override function getActions(): Array<_PlayerAction>
    {
      var actions = [];
      actions.push({
        id: 'channelRitual',
        type: ACTION_CULT,
        name: T('Channel the ritual ({stage}/{stages})', {
          stage: stage + 1,
          stages: STAGES,
        }),
        energy: 0,
        f: function() {
          // the base grows in a habitat, and every stage in the one the ritual began in: refuse
          // anywhere else and keep the ordeal, since success() removes it whatever onSuccess does
          if (game.location != LOCATION_AREA ||
              !game.area.isHabitat)
            {
              game.actionFailed(T('The ritual must be channelled in a habitat.'));
              return;
            }
          if (areaID >= 0 &&
              game.area.id != areaID)
            {
              game.actionFailed(T('The ritual must continue in the habitat where it began.'));
              return;
            }
          if (channelling)
            return;
          game.ui.closeWindow();
          channel();
        }
      });
      actions.push({
        id: 'annul',
        type: ACTION_CULT,
        name: T('Annul') + ' ' + Const.smallgray(T('(results in failure)')),
        energy: 0,
        f: function() {
          fail();
          game.ui.cult.setMenuState(STATE_ROOT);
          game.ui.updateWindow();
        }
      });
      return actions;
    }

// channels the next stage round the player; it counts when its animation ends, so a save during it
// drops the stage and keeps nothing half-done. the stage's vision opens then, except the last stage
// grows the base first, which opens its own
  function channel()
    {
      areaID = game.area.id;
      channelling = true;
      game.log(T('You channel the metamorphosis ritual ({stage}/{stages}).', {
        stage: stage + 1,
        stages: STAGES,
      }));
      game.scene.ritualFx(game.playerArea.x, game.playerArea.y, stage + 1, function() {
        channelling = false;
        stage++;
        if (stage < STAGES)
          showVision(visions[stage - 1], null);
        else success();
      });
    }

// opens a stage's vision: an occasio-style window with one button; onClose, when given, runs as it is
// endured
  function showVision(v: { title: String, text: String, img: String }, onClose: Void -> Void)
    {
      var params: _ChoiceParams = {
        title: T('{visio}: {title}', {
          visio: Const.col('occasio', T('Visio')),
          title: Loc.tr(v.title),
        }),
        text: Loc.tr(v.text),
        img: v.img,
        choices: [],
        buttons: [ T('Endure the vision') ],
        src: null,
        textClass: 'choice-occasio',
        // Dynamic: ui.Choice's callback type; a vision has nothing to pass back
        f: function(src: Dynamic, choiceID: Int) {
          if (onClose != null)
            onClose();
        }
      };
      game.ui.event({
        type: UIEVENT_STATE,
        state: UISTATE_CHOICE,
        obj: params
      });
    }

// creates the living base
  public override function onSuccess()
    {
      cult.level = 2;
      var spot = heartSpot();
      cult.base = new CultBase(game, game.area.id, spot.x, spot.y);
      RivalCult.generate(game, RIVAL_COMBAT);
      RivalCult.generate(game, RIVAL_NON_COMBAT);
      // the heart tears up once the last vision is endured (at once from `cu meta 2`, which skips the
      // stages), and the base's message waits for it to stand
      var birth = function() {
        cult.base.birth(function() {
          game.message({
            text: T('Cor Nefandum opens. Cultus Carnis enters its second form.'),
            col: 'cult'
          });
        });
      };
      if (stage >= STAGES)
        showVision(visions[STAGES - 1], birth);
      else birth();
    }

// the heart's anchor nearest the player whose whole footprint is walkable and holds no object or AI,
// the build rules (CultBase.validateBuild) minus the tileset lookup: isWalkable already counts a solid
// growth like biomineral. the player's own cell counts as free, the heart grows under it
  function heartSpot(): { x: Int, y: Int }
    {
      var area = game.area;
      var px = game.playerArea.x;
      var py = game.playerArea.y;
      for (r in 0...HEART_SEARCH + 1)
        for (dy in -r...r + 1)
          for (dx in -r...r + 1)
            {
              // the ring at this distance only
              if (Std.int(Math.max(Math.abs(dx), Math.abs(dy))) != r)
                continue;
              var free = true;
              for (pt in CultBaseConst.footprint(COR_NEFANDUM, px + dx, py + dy))
                if (!(pt.x == px && pt.y == py) &&
                    (!area.isWalkable(pt.x, pt.y) ||
                     area.hasObjectAt(pt.x, pt.y) ||
                     area.hasAI(pt.x, pt.y)))
                  {
                    free = false;
                    break;
                  }
              if (free)
                return {
                  x: px + dx,
                  y: py + dy,
                };
            }
      // ponytail: a habitat packed solid round the player keeps the old spot, overlap and all
      return {
        x: px,
        y: py,
      };
    }

// adds initiate action when Phase I is complete and player is in habitat
  public static function initiateAction(cult: Cult, actions: Array<_PlayerAction>)
    {
      if (cult.level != 1 ||
          !cult.metamorphosisPhaseIComplete ||
          cult.base != null)
        return;
      if (cult.game.location != LOCATION_AREA ||
          cult.game.area == null ||
          !cult.game.area.isHabitat)
        return;
      actions.push({
        id: 'metamorphosisPhaseII',
        type: ACTION_CULT,
        name: T('Metamorphosis, Phase II'),
        energy: 0,
        obj: {}
      });
    }
}
