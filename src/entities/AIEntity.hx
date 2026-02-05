// AI engine entity

package entities;

import js.html.CanvasRenderingContext2D;

import ai.AI;
import game.Game;

class AIEntity extends PawnEntity
{
  var ai: AI; // AI link
  // -1, 0: do not draw
  var alertx: Int; // alert frame (new draw)
  var isNPC: Bool;
  var isMissionTarget: Bool;


  public function new(vai: AI, g: Game, xx: Int, yy: Int)
    {
      super(g, xx, yy);

      alertx = -1;
      isNPC = false;
      isMissionTarget = false;
      ai = vai;
      type = "ai";
    }


// set alert image index
  public inline function setAlert(index: Int)
    {
      alertx = index;
    }

// ai entity draw
  public override function draw(ctx: CanvasRenderingContext2D)
    {
      // get targeting/target flags
      var showTargeting = false;
      var showTarget = false;
      if (game.ui.hud.state == HUD_TARGETING &&
          game.ui.hud.targeting.targetingAI == ai)
        showTargeting = true;
      if (game.ui.hud.targeting.target == ai &&
          game.ui.hud.targeting.isTargetVisibleOnScreen())
        showTarget = true;

      // draw target frame
      if (showTarget)
        drawImage(ctx, game.scene.images.entities,
          Const.FRAME_TARGET_FRAME,
          Const.ROW_REGION_ICON);

      // draw pawn image (mask -> entity -> text)
      super.draw(ctx);

      // draw alert icon
      if (alertx > 0)
        drawImage(ctx, game.scene.images.entities,
          alertx, Const.ROW_ALERT);
      // draw npc/mission target icon
      if (isNPC || isMissionTarget)
        drawImage(ctx, game.scene.images.entities,
          Const.FRAME_EVENT_NPC_AREA,
          Const.ROW_REGION_ICON);
      // draw cultist icon
      if (ai.isPlayerCultist())
        drawImage(ctx, game.scene.images.entities,
          Const.FRAME_CULTIST0,
          Const.ROW_EFFECT);

      // draw target reticle
      if (showTargeting)
        {
          ctx.shadowColor = 'rgba(0, 0, 0, 0.5)';
          ctx.shadowBlur = 5;
          ctx.shadowOffsetX = 1;
          ctx.shadowOffsetY = 1;
          drawImage(ctx, game.scene.images.entities,
            Const.FRAME_TARGET_RETICLE,
            Const.ROW_REGION_ICON);
          ctx.shadowColor = 'transparent';
        }
    }


// set npc flag
  public inline function setNPC()
    {
      isNPC = true;
    }

// set mission target flag
  public inline function setMissionTarget()
    {
      isMissionTarget = true;
    }
}
