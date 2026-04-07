// procedural region map image facade

package map;

import game.Game;
import js.Browser;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
#if electron
import js.node.Fs;
import js.Syntax;
#end

class Image extends Buildings
{
  public function new(g: Game)
    {
      super(g);
    }

#if electron
// dump the generated building rects for one region map seed
  function dumpBuildingRects()
    {
      var lines = [];
      lines.push('seed=' + mapSeed);
      lines.push('buildings=' + buildings.length);

      for (i in 0...buildings.length)
        {
          var building = buildings[i];
          lines.push('building ' + i +
            ' density=' + building.density +
            ' lot=' + building.lotX + ',' + building.lotY + ',' +
            building.lotWidth + 'x' + building.lotHeight +
            ' rects=' + building.rects.length);
          for (j in 0...building.rects.length)
            {
              var rect = building.rects[j];
              lines.push('  rect ' + j + ' ' +
                rect.x + ',' + rect.y + ',' + rect.width + 'x' + rect.height);
            }
        }

      Fs.writeFileSync('region_buildings.txt', lines.join('\n') + '\n');
    }

// render one debug mode into the current working canvas
  function renderDebugViewMode(mode: Int)
    {
      if (mode == MAP_DEBUG_VIEW_GROUND)
        {
          paintGround();
          return;
        }

      if (mode == MAP_DEBUG_VIEW_FOREST_RAW)
        {
          paintForestFieldDebug();
          return;
        }

      if (mode == MAP_DEBUG_VIEW_FOREST_MASK)
        {
          paintForestMaskDebug();
          return;
        }

      if (mode == MAP_DEBUG_VIEW_WOODS_RAW)
        {
          paintDarkWoodsFieldDebug();
          return;
        }

      if (mode == MAP_DEBUG_VIEW_WOODS_MASK)
        {
          paintDarkWoodsMaskDebug();
          return;
        }

      if (mode == MAP_DEBUG_VIEW_FOREST_EDGE)
        {
          paintForestEdgeDebug();
          return;
        }

      if (mode == MAP_DEBUG_VIEW_WOODS_THRESHOLD)
        {
          paintDarkWoodsThresholdDebug();
          return;
        }

      if (mode == MAP_DEBUG_VIEW_WOODS_SUPPORT)
        {
          paintDarkWoodsSupportDebug();
          return;
        }

      if (mode == MAP_DEBUG_VIEW_DARK_FOREST_PATCH_RAW)
        {
          paintDarkForestPatchFieldDebug();
          return;
        }

      if (mode == MAP_DEBUG_VIEW_DARK_FOREST_PATCH_THRESHOLD)
        {
          paintDarkForestPatchThresholdDebug();
          return;
        }

      if (mode == MAP_DEBUG_VIEW_DARK_FOREST_PATCH_MASK)
        {
          paintDarkForestPatchMaskDebug();
          return;
        }

      paintGround();
    }

// write one canvas to a png file
  function writeCanvasPNG(path: String, srcCanvas: CanvasElement)
    {
      var dataURL = srcCanvas.toDataURL('image/png');
      var base64Data = dataURL.substr(dataURL.indexOf(',') + 1);
      Fs.writeFileSync(path, Syntax.code("Buffer.from({0}, 'base64')", base64Data));
    }

// dump every map debug view to a cropped png file
  function dumpDebugViewPNGs()
    {
      var originalCanvas = canvas;
      var originalCtx = ctx;
      var views = [
        { mode: MAP_DEBUG_VIEW_GROUND, name: 'ground' },
        { mode: MAP_DEBUG_VIEW_FOREST_RAW, name: 'forest_raw' },
        { mode: MAP_DEBUG_VIEW_FOREST_MASK, name: 'forest_mask' },
        { mode: MAP_DEBUG_VIEW_WOODS_RAW, name: 'woods_raw' },
        { mode: MAP_DEBUG_VIEW_WOODS_MASK, name: 'woods_mask' },
        { mode: MAP_DEBUG_VIEW_FOREST_EDGE, name: 'forest_edge' },
        { mode: MAP_DEBUG_VIEW_WOODS_THRESHOLD, name: 'woods_threshold' },
        { mode: MAP_DEBUG_VIEW_WOODS_SUPPORT, name: 'woods_support' },
        { mode: MAP_DEBUG_VIEW_DARK_FOREST_PATCH_RAW, name: 'dark_forest_patch_raw' },
        { mode: MAP_DEBUG_VIEW_DARK_FOREST_PATCH_THRESHOLD, name: 'dark_forest_patch_threshold' },
        { mode: MAP_DEBUG_VIEW_DARK_FOREST_PATCH_MASK, name: 'dark_forest_patch_mask' },
      ];

      for (viewIndex in 0...views.length)
        {
          var view = views[viewIndex];
          var prefix = StringTools.lpad(Std.string(viewIndex + 1), '0', 2);
          canvas = Browser.document.createCanvasElement();
          canvas.width = fullPixelWidth;
          canvas.height = fullPixelHeight;
          ctx = canvas.getContext2d({});
          renderDebugViewMode(view.mode);
          cropVisibleRegion();
          writeCanvasPNG('region_debug_' + mapSeed + '_' + prefix + '_' + view.name + '.png', canvas);
        }

      canvas = originalCanvas;
      ctx = originalCtx;
    }
#end

// generate the cached region image
  public function generate(): CanvasElement
    {
#if mydebug
      var totalStartTS = haxe.Timer.stamp() * 1000.0;
      var phaseStartTS = totalStartTS;
#end
      initRegionMetrics();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.initRegionMetrics', phaseStartTS);
#end
      initCanvas();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.initCanvas', phaseStartTS);
#end
      initRandom();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.initRandom', phaseStartTS);
      traceMapProfileSummary('image.seed=' + mapSeed);
#end

      densityField = buildDensityField();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.buildDensityField', phaseStartTS);
#end
      areaTypes = buildAreaTypeField();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.buildAreaTypeField', phaseStartTS);
#end
      groundNeighborhoodField = buildGroundNeighborhoodField(1);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.buildGroundNeighborhoodField', phaseStartTS);
#end
      darkForestPatchLobes = buildDarkForestPatchLobes();
      darkForestPatchLobeBins = buildDarkForestPatchLobeBins();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.buildDarkForestPatchLobes', phaseStartTS);
#end
      darkForestPatchCoverageTarget = getDarkForestPatchCoverageTarget();
      darkForestPatchThresholdValue = computeDarkForestPatchThresholdValue();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.computeDarkForestPatchThresholdValue', phaseStartTS);
      traceMapProfileSummary('image.darkForestPatchCoverageTarget=' + darkForestPatchCoverageTarget);
      traceMapProfileSummary('image.darkForestPatchThreshold=' + darkForestPatchThresholdValue);
#end
      overallDensity = sampleAverageDensity(0, 0, fullPixelWidth, fullPixelHeight);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.sampleAverageDensity', phaseStartTS);
#end
      paintGround();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.paintGround', phaseStartTS);
#end
      paintForests();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.paintForests', phaseStartTS);
#end
#if electron
      if (MAP_DEBUG_DUMP_PNGS)
        dumpDebugViewPNGs();
#end
      if (paintDebugViewIfRequested())
        {
          cropVisibleRegion();
#if mydebug
          phaseStartTS = nextMapProfileTimestamp('image.cropVisibleRegion.debug', phaseStartTS);
          traceMapProfileSummary('image.debugView=' + MAP_DEBUG_VIEW_MODE);
          nextMapProfileTimestamp('image.total.debug', totalStartTS);
#end
          return canvas;
        }

      if (!ENABLE_REGION_CITY_CONTENT)
        {
          cropVisibleRegion();
#if mydebug
          phaseStartTS = nextMapProfileTimestamp('image.cropVisibleRegion.noCity', phaseStartTS);
          traceMapProfileSummary('image.summary roads=0 blocks=0 parcels=0 buildings=0' +
            ' fullPixels=' + fullPixelWidth + 'x' + fullPixelHeight);
          nextMapProfileTimestamp('image.total', totalStartTS);
#end
          return canvas;
        }

      roads = generateRoadGraph();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.generateRoadGraph', phaseStartTS);
#end
      roadMasks = rasterizeRoadMasks(roads);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.rasterizeRoadMasks', phaseStartTS);
#end
      blocks = buildBlocks();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.buildBlocks', phaseStartTS);
#end
      parcels = buildParcels(blocks);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.buildParcels', phaseStartTS);
#end
      buildings = generateBuildings(parcels);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.generateBuildings', phaseStartTS);
#end
#if electron
      dumpBuildingRects();
#if mydebug
      traceMapProfileSummary('image.buildingDump=region_buildings.txt');
#end
#end
      paintOpenParcels(parcels);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.paintOpenParcels', phaseStartTS);
#end
      paintBuildings();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.paintBuildings', phaseStartTS);
#end
      paintRoads();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.paintRoads', phaseStartTS);
#end

      cropVisibleRegion();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.cropVisibleRegion', phaseStartTS);
#end
      applyFinalImagePostProcess();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.applyFinalImagePostProcess', phaseStartTS);
      traceMapProfileSummary('image.summary roads=' + roads.length +
        ' blocks=' + blocks.length +
        ' parcels=' + parcels.length +
        ' buildings=' + buildings.length +
        ' fullPixels=' + fullPixelWidth + 'x' + fullPixelHeight);
      nextMapProfileTimestamp('image.total', totalStartTS);
#end
      return canvas;
    }

// draw visible region source rect to the destination
  public function drawTo(ctx: CanvasRenderingContext2D,
      srcX: Int, srcY: Int, srcW: Int, srcH: Int,
      dstX: Int, dstY: Int, dstW: Int, dstH: Int)
    {
      if (canvas == null)
        return;

      untyped ctx.imageSmoothingEnabled = true;
      ctx.drawImage(canvas,
        srcX, srcY, srcW, srcH,
        dstX, dstY, dstW, dstH);
    }

}
