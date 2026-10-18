// the city's alley-mouth fences (game.CityAreaGenerator.placeFences): one upright panel per fence
// cell, across its middle and parallel to the kerb it faces, spanning the cell so it meets the
// buildings either side. downtown is chain-link, the residential streets boards, the slums broken
// boards. the art carries its own post and top rail, so a fence is one quad per cell and one mesh
// per area. built AFTER the chunk pass: one merged mesh bucketed by its origin would cull whenever
// that chunk left the frustum (the steam's trap), while at the scene root three culls it by its
// bounding sphere
package render.world;

import three.Three;
import citygen.CityConfig;
import game.AreaGame;
import render.facility.FacilityGeom;
import render.world.MeshBuf;

class CityFences
{
  static inline var CELL = CityConfig.CELL;
  // chain-link: one cell high, the square panel tiled once per cell along the run
  static inline var CHAIN_H = CELL;
  // boards: the 4:3 panel tiled once per cell along the run, so its height is three quarters of one
  public static inline var WOOD_H = CELL * 0.75;
  static inline var TEX_CHAIN = 'textures/downtown/fence-chainlink.png';
  static inline var TEX_WOOD = 'textures/city/fence-wood.png';
  static inline var TEX_WOOD_BROKEN = 'textures/slums/fence-wood.png';
  static inline var CUT = 0.3; // alpha cut for the chain-link wire (3d-geometry.md: thin wire at 128 texels/unit)

// add this area's fences to the scene, if it has any
  public static function build(scene:Scene, area:AreaGame):Void
    {
      var chain = (area.typeID == AREA_CITY_HIGH);
      var tall = (chain ? CHAIN_H : WOOD_H);
      var b = MeshBufTools.make();
      for (row in 0...area.height)
        for (col in 0...area.width)
          if (isFence(area.getCellType(col, row)))
            panel(b, area, col, row, tall);
      if (b.idx.length == 0)
        return;
      var tex = (chain ? TEX_CHAIN :
        (area.typeID == AREA_CITY_LOW ? TEX_WOOD_BROKEN : TEX_WOOD));
      var mat = new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: THREE.DoubleSide,
      });
      // the chain-link and the slums' broken boards are cut, the residential boards are solid
      if (tex != TEX_WOOD)
        mat.alphaTest = CUT;
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.name = 'city fences';
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// one fence cell's panel: across the cell's middle, parallel to its one street side. u runs one
// image per cell in world space, offset half an image so the painted centre post stands on the
// cell boundary; v maps the image's height onto the fence's
  static function panel(b:MeshBuf, area:AreaGame, col:Int, row:Int, tall:Float):Void
    {
      var c = CityConfig.cellToWorld(col, row);
      var h = CELL / 2;
      // the street side decides the run: a street north or south runs the fence along x
      var alongX = false;
      for (i in 0...Const.dir4x.length)
        if (Const.dir4y[i] != 0 &&
            isStreet(area.getCellType(col + Const.dir4x[i], row + Const.dir4y[i])))
          alongX = true;
      var a0 = (alongX ? c.x : c.z) - h;
      var a1 = a0 + CELL;
      var p = (alongX ? c.z : c.x);
      var u0 = a0 / CELL + 0.5;
      var u1 = a1 / CELL + 0.5;
      if (alongX)
        MeshBufTools.quad(b, [a0, 0, p], [a1, 0, p], [a1, tall, p], [a0, tall, p],
          [u0, 0, u1, 0, u1, 1, u0, 1]);
      else
        MeshBufTools.quad(b, [p, 0, a1], [p, 0, a0], [p, tall, a0], [p, tall, a1],
          [u1, 0, u0, 0, u0, 1, u1, 1]);
    }

// is this tile a fence
  public static inline function isFence(t:Int):Bool
    {
      return t == Const.TILE_CITY_FENCE_CHAIN ||
        t == Const.TILE_CITY_FENCE_WOOD;
    }

// is this tile the street: pavement, road or a crossing (game.CityAreaGenerator's own test)
  static inline function isStreet(t:Int):Bool
    {
      return t == Const.TILE_WALKWAY ||
        t == Const.TILE_ROAD ||
        t == Const.TILE_CROSSWALKV ||
        t == Const.TILE_CROSSWALKH;
    }
}
