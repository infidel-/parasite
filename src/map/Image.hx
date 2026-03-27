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
      initRegionMetrics();
      initCanvas();
      initRandom();

      densityField = buildDensityField();
      areaTypes = buildAreaTypeField();
      overallDensity = sampleAverageDensity(0, 0, fullPixelWidth, fullPixelHeight);
      paintGround();

      roads = generateRoadGraph();
      roadMasks = rasterizeRoadMasks(roads);
      paintRoads();

      cropVisibleRegion();
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
