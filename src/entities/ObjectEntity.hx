// objects engine entity

package entities;

import js.html.CanvasRenderingContext2D;
import objects.AreaObject;
import game.Game;
import objects.base.BaseOrganObject;

class ObjectEntity extends Entity
{
  var object: AreaObject; // object link

  public function new(o: AreaObject, g: Game, xx: Int, yy: Int)
    {
      super(g, Const.LAYER_OBJECT);
      type = 'object';
      object = o;
      mx = xx;
      my = yy;
    }

  public override function draw(ctx: CanvasRenderingContext2D)
    {
      super.draw(ctx);
      if (object.type == 'door')
        {
          var door: objects.Door = cast object;
          if (door.isLocked)
            drawImage(ctx,
              game.scene.images.entities,
              Const.FRAME_LOCKED_ICON,
              Const.ROW_OBJECT);
        }
      else if (object.type == 'base_organ')
        drawBaseOrganOverlay(ctx);

    }

// draws base organ durability overlays
  function drawBaseOrganOverlay(ctx: CanvasRenderingContext2D)
    {
      var obj: BaseOrganObject = cast object;
      if (obj.basePartIndex != 0)
        return;
      var organ = obj.getOrgan();
      if (organ == null)
        return;
      var damaged = organ.health < organ.maxHealth() || organ.broken;
      if (!damaged)
        return;

      // find bounding box of organ footprint
      var minX = 99999;
      var minY = 99999;
      var maxX = -1;
      var maxY = -1;
      for (pt in organ.footprint())
        {
          if (pt.x < minX)
            minX = pt.x;
          if (pt.y < minY)
            minY = pt.y;
          if (pt.x > maxX)
            maxX = pt.x;
          if (pt.y > maxY)
            maxY = pt.y;
        }

      // draw health bar and broken x if needed
      drawBaseOrganHealthBar(ctx, organ.health, organ.maxHealth(),
        minX, minY, maxX, maxY);
      if (organ.broken)
        drawBaseOrganBrokenX(ctx, minX, minY, maxX, maxY);
    }

// draws a compact health bar for damaged base organs
  function drawBaseOrganHealthBar(ctx: CanvasRenderingContext2D,
      health: Int, maxHealth: Int, minX: Int, minY: Int,
      maxX: Int, maxY: Int)
    {
      var tile = Const.TILE_SIZE;
      var tilesWide = maxX - minX + 1;
      var barHeight = Std.int(Math.max(4, 5 * game.config.mapScale));
      var margin = Std.int(Math.max(2, 3 * game.config.mapScale));
      var x = (minX - game.scene.cameraTileX1) * tile + margin;
      var y = (minY - game.scene.cameraTileY1) * tile + margin;
      var width = tile * tilesWide - margin * 2;
      var ratio = maxHealth > 0 ? health / maxHealth : 0;
      if (ratio < 0)
        ratio = 0;
      else if (ratio > 1)
        ratio = 1;

      ctx.fillStyle = 'rgba(0, 0, 0, 0.75)';
      ctx.fillRect(x - 1, y - 1, width + 2, barHeight + 2);
      ctx.strokeStyle = 'rgba(220, 220, 220, 0.9)';
      ctx.lineWidth = 1;
      ctx.strokeRect(x - 1, y - 1, width + 2, barHeight + 2);
      ctx.fillStyle = 'rgba(40, 210, 70, 0.95)';
      ctx.fillRect(x, y, Std.int(width * ratio), barHeight);
    }

// draws a red x over broken base organs
  function drawBaseOrganBrokenX(ctx: CanvasRenderingContext2D,
      minX: Int, minY: Int, maxX: Int, maxY: Int)
    {
      var tile = Const.TILE_SIZE;
      var margin = Std.int(Math.max(4, 5 * game.config.mapScale));
      var x1 = (minX - game.scene.cameraTileX1) * tile + margin;
      var y1 = (minY - game.scene.cameraTileY1) * tile + margin;
      var x2 = (maxX - game.scene.cameraTileX1 + 1) * tile - margin;
      var y2 = (maxY - game.scene.cameraTileY1 + 1) * tile - margin;

      ctx.save();
      ctx.strokeStyle = 'rgba(210, 20, 20, 0.9)';
      ctx.lineWidth = Math.max(2, 3 * game.config.mapScale);
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.moveTo(x2, y1);
      ctx.lineTo(x1, y2);
      ctx.stroke();
      ctx.restore();
    }
  }
