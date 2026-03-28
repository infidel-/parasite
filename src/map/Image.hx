// procedural region map image facade

package map;

import game.Game;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;

class Image extends Buildings
{
  public function new(g: Game)
    {
      super(g);
    }

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
#end

      densityField = buildDensityField();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.buildDensityField', phaseStartTS);
#end
      areaTypes = buildAreaTypeField();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.buildAreaTypeField', phaseStartTS);
#end
      overallDensity = sampleAverageDensity(0, 0, fullPixelWidth, fullPixelHeight);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.sampleAverageDensity', phaseStartTS);
#end
      paintGround();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('image.paintGround', phaseStartTS);
#end

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
