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


  public function new(vai: AI, g: Game, xx: Int, yy: Int)
    {
      super(g, xx, yy);

      alertx = -1;
      isNPC = false;
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
      var x = (mx * Const.TILE_SIZE_CLEAN - game.scene.cameraX) * game.config.mapScale;
      var y = (my * Const.TILE_SIZE_CLEAN - game.scene.cameraY) * game.config.mapScale;

      // draw pawn image (mask -> entity -> text)
      super.draw(ctx);

      // draw alert icon
      if (alertx > 0)
        ctx.drawImage(game.scene.images.entities,
          alertx * Const.TILE_SIZE_CLEAN, 
          Const.ROW_ALERT * Const.TILE_SIZE_CLEAN,
          Const.TILE_SIZE_CLEAN,
          Const.TILE_SIZE_CLEAN,
          x,
          y,
          Const.TILE_SIZE_CLEAN,
          Const.TILE_SIZE_CLEAN);
      // draw npc icon

      if (isNPC)
        ctx.drawImage(game.scene.images.entities,
          Const.FRAME_EVENT_NPC_AREA * Const.TILE_SIZE_CLEAN, 
          Const.ROW_REGION_ICON * Const.TILE_SIZE_CLEAN,
          Const.TILE_SIZE_CLEAN,
          Const.TILE_SIZE_CLEAN,
          x,
          y,
          Const.TILE_SIZE_CLEAN,
          Const.TILE_SIZE_CLEAN);
    }


// set alert image index
  public inline function setNPC()
    {
      isNPC = true;
    }
}
