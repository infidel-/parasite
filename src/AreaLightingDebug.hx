// area lighting debug helpers and middle-click inspection output

import js.html.CanvasRenderingContext2D;
import ai.AI;
import game.AreaGame;
import lighting.*;
import tiles.*;

@:access(AreaLighting)
class AreaLightingDebug
{
// marker radius in tiles for light source debug rendering
  static var DEBUG_LIGHT_MARKER_RADIUS_TILES = 0.11;
// marker stroke width in tile fractions for debug rendering
  static var DEBUG_LIGHT_MARKER_STROKE_WIDTH_TILES = 0.03;
// marker fill alpha used for light source debug rendering
  static var DEBUG_LIGHT_MARKER_FILL_ALPHA = 0.28;
// marker ring alpha used for light source debug rendering
  static var DEBUG_LIGHT_MARKER_RING_ALPHA = 0.95;

// draw bright source markers for all active light emitters
  public static function drawDebugLightMarkers(areaLighting: AreaLighting,
      ctx: CanvasRenderingContext2D)
    {
      var game = areaLighting.game;
      if (!game.player.vars.debugLightsEnabled)
        return;

      var area = game.area;
      if (!areaLighting.hasLighting(area))
        return;

      areaLighting.syncAreaState(area);
      var markers = collectDebugLightMarkers(areaLighting, area);
      if (markers.length <= 0)
        return;

      var scene = areaLighting.scene;
      var rect = area.getVisibleRect();
      var radius = DEBUG_LIGHT_MARKER_RADIUS_TILES * Const.TILE_SIZE;
      var strokeWidth = DEBUG_LIGHT_MARKER_STROKE_WIDTH_TILES * Const.TILE_SIZE;
      if (strokeWidth < 1)
        strokeWidth = 1;

      ctx.save();
      ctx.globalCompositeOperation = 'source-over';
      ctx.lineWidth = strokeWidth;
      for (marker in markers)
        {
          var tileX = Std.int(Math.floor(marker.x));
          var tileY = Std.int(Math.floor(marker.y));
          if (tileX < rect.x1 ||
              tileY < rect.y1 ||
              tileX >= rect.x2 ||
              tileY >= rect.y2)
            continue;

          var sx = (marker.x - scene.cameraTileX1) * Const.TILE_SIZE;
          var sy = (marker.y - scene.cameraTileY1) * Const.TILE_SIZE;
          var rgb = (marker.castsShadows ? '0, 0, 0' : '255, 255, 255');
          ctx.fillStyle = 'rgba(' + rgb + ', ' + DEBUG_LIGHT_MARKER_FILL_ALPHA + ')';
          ctx.strokeStyle = 'rgba(' + rgb + ', ' + DEBUG_LIGHT_MARKER_RING_ALPHA + ')';
          ctx.beginPath();
          ctx.arc(sx, sy, radius, 0, Math.PI * 2, false);
          ctx.fill();
          ctx.stroke();
        }
      ctx.restore();
    }

// collect debug lines for one tile's light stamps and local decoration context
  public static function getTileLightDebugLines(areaLighting: AreaLighting,
      area: AreaGame, x: Int, y: Int): Array<String>
    {
      var lines: Array<String> = [];
      lines.push('lightDebug tile=(' + x + ',' + y + ')');
      if (!areaLighting.hasLighting(area))
        {
          lines.push(' lighting=disabled');
          return lines;
        }

      if (area.tiles == null ||
          area.tiles.length == 0)
        area.initTilesFromCells();

      var matchingStamps: Array<_AreaLightStamp> = [];
      for (stamp in areaLighting.getAreaLightStamps(area))
        if (Std.int(Math.floor(stamp.x)) == x &&
            Std.int(Math.floor(stamp.y)) == y)
          matchingStamps.push(stamp);

      lines.push(' stamps=' + matchingStamps.length);
      for (stamp in matchingStamps)
        {
          var sourceGroupID = (stamp.sourceGroupID != null ?
            stamp.sourceGroupID : '-');
          var falloffProfile = (stamp.falloffProfile != null ?
            stamp.falloffProfile : '-');
          lines.push('  kind=' + stamp.kind +
            ' pos=' + Const.round2(stamp.x) + ',' + Const.round2(stamp.y) +
            ' radius=' + Const.round2(stamp.radiusTiles) +
            ' intensity=' + Const.round2(stamp.intensity) +
            ' tint=' + stamp.tintR + ',' + stamp.tintG + ',' + stamp.tintB +
            ' castsShadows=' + areaLighting.isProjectedShadowEmitterStamp(stamp) +
            ' group=' + sourceGroupID +
            ' falloff=' + falloffProfile);
        }

      appendTileLightDebugContext(areaLighting, lines, area, 'tile', x, y);
      appendTileLightDebugContext(areaLighting, lines, area, 'tileAbove', x, y - 1);
      return lines;
    }

// collect debug lines for one tile's dynamic projected-shadow setup
  public static function getTileDynamicShadowDebugLines(areaLighting: AreaLighting,
      area: AreaGame, x: Int, y: Int): Array<String>
    {
      var lines: Array<String> = [];
      lines.push('shadowDebug tile=(' + x + ',' + y + ')');
      if (!areaLighting.hasLighting(area))
        {
          lines.push(' lighting=disabled');
          return lines;
        }

      var scene = areaLighting.scene;
      var game = areaLighting.game;
      var mapWidth = Std.int(Math.ceil(area.width *
        AreaLighting.ATMOS_LIGHTMAP_TILE_SIZE));
      var mapHeight = Std.int(Math.ceil(area.height *
        AreaLighting.ATMOS_LIGHTMAP_TILE_SIZE));
      var mapScale = areaLighting.getAtmosMapScreenScale();
      var drawX = areaLighting.getAtmosMapScreenX(0);
      var drawY = areaLighting.getAtmosMapScreenY(0);
      var drawW = mapWidth * mapScale;
      var drawH = mapHeight * mapScale;

      lines.push(' camera=' + scene.cameraX + ',' + scene.cameraY +
        ' tile1=' + scene.cameraTileX1 + ',' + scene.cameraTileY1 +
        ' sub=' + scene.cameraSubX + ',' + scene.cameraSubY);
      lines.push(' lightmap=' + mapWidth + 'x' + mapHeight +
        ' screen=' + scene.canvas.width + 'x' + scene.canvas.height);
      lines.push(' paintMap draw=' +
        Const.round2(drawX) + ',' +
        Const.round2(drawY) +
        ' size=' + Const.round2(drawW) + ',' +
        Const.round2(drawH) +
        ' scale=' + Const.round2(mapScale));

      if (game.playerArea.x == x &&
          game.playerArea.y == y &&
          game.player.state == PLR_STATE_PARASITE)
        {
          lines.push(' dynamicCaster=player-parasite none');
          return lines;
        }

      var debugAI = getTileDynamicShadowDebugAI(areaLighting, area, x, y);
      if (debugAI == null)
        {
          lines.push(' dynamicCaster=-');
          return lines;
        }

      var sprite = areaLighting.getAIProjectedShadowSpriteSource(debugAI);
      if (sprite == null)
        {
          lines.push(' dynamicCaster=ai#' + debugAI.id +
            ' type=' + debugAI.type + ' sprite=-');
          return lines;
        }

      var caster: _ProjectedShadowCaster = {
        layerID: -1,
        image: sprite.image,
        maskKey: 'ai:' + sprite.imageKey + ':' + sprite.srcRow + ':' +
          sprite.srcCol + ':1:1',
        srcRow: sprite.srcRow,
        srcCol: sprite.srcCol,
        blockW: 1,
        blockH: 1,
        centerX: debugAI.x + 0.5,
        centerY: debugAI.y + 0.5,
        skipSelfShadow: true,
      };

      var casterMapX = areaLighting.toMapX(caster.centerX);
      var casterMapY = areaLighting.toMapY(caster.centerY);
      var casterScreenX = (caster.centerX - scene.cameraTileX1) * Const.TILE_SIZE;
      var casterScreenY = (caster.centerY - scene.cameraTileY1) * Const.TILE_SIZE;
      var casterPaintX = areaLighting.getAtmosMapScreenX(casterMapX);
      var casterPaintY = areaLighting.getAtmosMapScreenY(casterMapY);
      lines.push(' dynamicCaster=ai#' + debugAI.id +
        ' type=' + debugAI.type +
        ' center=' + Const.round2(caster.centerX) + ',' +
        Const.round2(caster.centerY) +
        ' visible=' + (debugAI.entity != null &&
          debugAI.entity.isVisible()) +
        ' los=' + (!game.player.vars.losEnabled ||
          game.playerArea.sees(debugAI.x, debugAI.y)));
      lines.push('  sprite=' + sprite.imageKey + ':' + sprite.srcRow + ',' +
        sprite.srcCol + ' mask=' + caster.maskKey);
      lines.push('  screen actual=' + Const.round2(casterScreenX) + ',' +
        Const.round2(casterScreenY) + ' paint=' +
        Const.round2(casterPaintX) + ',' +
        Const.round2(casterPaintY) + ' delta=' +
        Const.round2(casterPaintX - casterScreenX) + ',' +
        Const.round2(casterPaintY - casterScreenY));
      if (sprite.image == null ||
          !sprite.image.complete ||
          sprite.image.naturalWidth <= 0)
        lines.push('  mask=asset-pending');
      else
        {
          var mask = areaLighting.getProjectedShadowMaskForSource(caster.maskKey,
            sprite.image, caster.srcRow, caster.srcCol,
            caster.blockW, caster.blockH);
          lines.push('  maskPoints=' + (mask != null ? mask.points.length : 0) +
            ' spriteDrawCropY=+1 shadowMaskCropY=+0');
        }

      var emitters = areaLighting.collectProjectedShadowEmitters(
        areaLighting.getAreaLightStamps(area));
      var hits = areaLighting.getNearestLayoutShadowEmitters(area, caster,
        emitters);
      var usedByKey = new Map<String, Bool>();
      for (hit in hits)
        usedByKey[hit.emitter.x + ':' + hit.emitter.y] = true;

      var maxDistSq = AreaLighting.PROJECTED_SHADOW_MAX_DISTANCE_TILES *
        AreaLighting.PROJECTED_SHADOW_MAX_DISTANCE_TILES;
      var emitterInfos: Array<_DynamicShadowDebugEmitterInfo> = [];
      for (emitter in emitters)
        {
          var dx = caster.centerX - emitter.x;
          var dy = caster.centerY - emitter.y;
          var distSq = dx * dx + dy * dy;
          var isInRange = (distSq > 0.0001 &&
            distSq <= maxDistSq);
          var hasLOS = false;
          var isInsideCaster = false;
          if (isInRange)
            {
              hasLOS = areaLighting.hasProjectedShadowEmitterLineOfSight(area,
                emitter.x, emitter.y, caster.centerX, caster.centerY);
              isInsideCaster = areaLighting.isEmitterInsideProjectedShadowCaster(
                emitter, caster);
            }
          emitterInfos.push({
            emitter: emitter,
            distSq: distSq,
            isInRange: isInRange,
            hasLOS: hasLOS,
            isInsideCaster: isInsideCaster,
            isUsed: usedByKey[emitter.x + ':' + emitter.y],
          });
        }
      emitterInfos.sort((a, b) -> {
        if (a.distSq < b.distSq)
          return -1;
        if (a.distSq > b.distSq)
          return 1;
        return 0;
      });

      lines.push(' emitters total=' + emitters.length +
        ' used=' + hits.length +
        ' maxDist=' + AreaLighting.PROJECTED_SHADOW_MAX_DISTANCE_TILES);
      for (info in emitterInfos)
        {
          if (!info.isUsed)
            continue;
          var emitterMapX = areaLighting.toMapX(info.emitter.x);
          var emitterMapY = areaLighting.toMapY(info.emitter.y);
          var emitterScreenX = (info.emitter.x - scene.cameraTileX1) *
            Const.TILE_SIZE;
          var emitterScreenY = (info.emitter.y - scene.cameraTileY1) *
            Const.TILE_SIZE;
          var emitterPaintX = areaLighting.getAtmosMapScreenX(emitterMapX);
          var emitterPaintY = areaLighting.getAtmosMapScreenY(emitterMapY);
          lines.push('  used emitter=' +
            Const.round2(info.emitter.x) + ',' +
            Const.round2(info.emitter.y) +
            ' dist=' + Const.round2(Math.sqrt(info.distSq)) +
            ' los=' + info.hasLOS +
            ' inside=' + info.isInsideCaster +
            ' actual=' + Const.round2(emitterScreenX) + ',' +
            Const.round2(emitterScreenY) +
            ' paint=' + Const.round2(emitterPaintX) + ',' +
            Const.round2(emitterPaintY) +
            ' delta=' +
            Const.round2(emitterPaintX - emitterScreenX) + ',' +
            Const.round2(emitterPaintY - emitterScreenY));
        }

      var rejected = 0;
      for (info in emitterInfos)
        {
          if (info.isUsed ||
              !info.isInRange)
            continue;
          lines.push('  reject emitter=' +
            Const.round2(info.emitter.x) + ',' +
            Const.round2(info.emitter.y) +
            ' dist=' + Const.round2(Math.sqrt(info.distSq)) +
            ' los=' + info.hasLOS +
            ' inside=' + info.isInsideCaster);
          rejected++;
          if (rejected >= 4)
            break;
        }

      if (hits.length == 0)
        {
          var farShown = 0;
          for (info in emitterInfos)
            {
              if (info.isInRange)
                continue;
              lines.push('  outOfRange emitter=' +
                Const.round2(info.emitter.x) + ',' +
                Const.round2(info.emitter.y) +
                ' dist=' + Const.round2(Math.sqrt(info.distSq)));
              farShown++;
              if (farShown >= 2)
                break;
            }
        }
      return lines;
    }

// get the dynamic-shadow actor for one clicked tile
  static function getTileDynamicShadowDebugAI(areaLighting: AreaLighting,
      area: AreaGame, x: Int, y: Int): AI
    {
      var game = areaLighting.game;
      if (game.player.state == PLR_STATE_HOST &&
          game.player.host != null &&
          game.playerArea.x == x &&
          game.playerArea.y == y)
        return game.player.host;
      return area.getAI(x, y);
    }

// append local tile decoration and object details for light debugging
  static function appendTileLightDebugContext(areaLighting: AreaLighting,
      lines: Array<String>, area: AreaGame,
      label: String, x: Int, y: Int)
    {
      if (x < 0 ||
          y < 0 ||
          x >= area.width ||
          y >= area.height)
        {
          lines.push(' ' + label + '=out-of-bounds');
          return;
        }

      var tileset = areaLighting.scene.images.getTileset(area.getTilesetTypeID());
      var undergroundLab: UndergroundLab = null;
      if (Std.isOfType(tileset, UndergroundLab))
        undergroundLab = cast tileset;
      var tileID = area.getCellType(x, y);
      var tile = area.getTiles()[x][y];
      var decorationInfo: Array<String> = [];
      if (tile != null &&
          tile.decoration != null)
        for (decoration in tile.decoration)
          decorationInfo.push(getTileLightDebugDecorationInfo(areaLighting,
            area, undergroundLab, tileID, decoration));

      var objectInfo: Array<String> = [];
      for (o in area.getObjectsAt(x, y))
        objectInfo.push(o.type + '#' + o.id);

      lines.push(' ' + label + ' cell=' + tileID +
        ' ' + area.getCellTypeString(x, y) +
        ' decor=' + (decorationInfo.length > 0 ?
          decorationInfo.join(' | ') : '-'));
      lines.push(' ' + label + ' objects=' + (objectInfo.length > 0 ?
        objectInfo.join(',') : '-'));
    }

// build one debug string for a decoration entry using tile-aware layer resolution
  static function getTileLightDebugDecorationInfo(areaLighting: AreaLighting,
      area: AreaGame, undergroundLab: UndergroundLab, tileID: Int,
      decoration: tiles.Decoration): String
    {
      var iconInfo = '-';
      if (decoration.icon != null)
        iconInfo = decoration.icon.row + ',' + decoration.icon.col;
      var tagInfo = (decoration.tag != null ? decoration.tag : '-');
      var layerKind = 'layer';
      if (undergroundLab != null)
        layerKind = (undergroundLab.isWallTile(tileID) ? 'wallLayer' : 'floorLayer');
      return layerKind + '=' + decoration.layerID +
        ',icon=' + iconInfo +
        ',tag=' + tagInfo +
        ',source=' + getTileLightDebugDecorationSourceID(
          areaLighting, area, undergroundLab, tileID, decoration);
    }

// resolve one debug-friendly decoration source id for a tile decoration
  static function getTileLightDebugDecorationSourceID(areaLighting: AreaLighting,
      area: AreaGame, undergroundLab: UndergroundLab, tileID: Int,
      decoration: tiles.Decoration): String
    {
      if (undergroundLab == null ||
          decoration.icon == null)
        return '-';
      return UndergroundLabAreaLighting.getDebugDecorationSourceID(
        undergroundLab, tileID, decoration);
    }

// collect deduplicated light source marker centers for debug overlay
  static function collectDebugLightMarkers(areaLighting: AreaLighting,
      area: AreaGame): Array<_DebugLightMarker>
    {
      var markers: Array<_DebugLightMarker> = [];
      var markerByPos: Map<String, _DebugLightMarker> = new Map();
      for (stamp in areaLighting.getAreaLightStamps(area))
        {
          var key = stamp.x + ':' + stamp.y;
          var marker = markerByPos.get(key);
          var castsShadows = areaLighting.isProjectedShadowEmitterStamp(stamp);
          if (marker == null)
            {
              marker = {
                x: stamp.x,
                y: stamp.y,
                castsShadows: castsShadows,
              };
              markerByPos.set(key, marker);
              markers.push(marker);
            }
          else if (castsShadows)
            marker.castsShadows = true;
        }

      for (pulse in areaLighting.transientAtmosphereLights)
        {
          var key = pulse.x + ':' + pulse.y;
          if (markerByPos.exists(key))
            continue;
          var marker: _DebugLightMarker = {
            x: pulse.x,
            y: pulse.y,
            castsShadows: false,
          };
          markerByPos.set(key, marker);
          markers.push(marker);
        }
      return markers;
    }
}
