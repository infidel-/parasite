// the city's alley-mouth fences (game.CityAreaGenerator.placeFences): one upright panel per fence
// cell, across its middle and parallel to the kerb it faces, spanning the cell so it meets the
// buildings either side. downtown is chain-link, the residential streets boards, the slums broken
// boards. the art carries its own post and top rail, so a fence is one quad per cell and one mesh
// per area. the mouth cells a fenced alley leaves open (one per open run) take the same panel with
// a hole broken through it, a second mesh. built AFTER the chunk pass: one merged
// mesh bucketed by its origin would cull whenever that chunk left the frustum (the steam's trap),
// while at the scene root three culls it by its bounding sphere
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

// add this area's fences and fence holes to the scene, if it has any
  public static function build(scene:Scene, area:AreaGame):Void
    {
      var chain = (area.typeID == AREA_CITY_HIGH);
      var tall = (chain ? CHAIN_H : WOOD_H);
      var fences = MeshBufTools.make();
      var holes = MeshBufTools.make();
      var open = openMouths(area);
      for (row in 0...area.height)
        for (col in 0...area.width)
          if (isFence(area.getCellType(col, row)))
            panel(fences, area, col, row, tall);
          else if (open.exists(row * area.width + col))
            panel(holes, area, col, row, tall);
      var tex = (chain ? TEX_CHAIN :
        (area.typeID == AREA_CITY_LOW ? TEX_WOOD_BROKEN : TEX_WOOD));
      add(scene, fences, tex, 'city fences');
      // every fence's art has a '-hole' twin
      add(scene, holes, StringTools.replace(tex, '.png', '-hole.png'), 'city fence holes');
    }

// one merged mesh of panels wearing this art, if there are any
  static function add(scene:Scene, b:MeshBuf, tex:String, name:String):Void
    {
      if (b.idx.length == 0)
        return;
      var map = Textures.loadTexture(tex, 'wall', 1);
      // v maps 0..1 once, so a repeating v filters the bottom row into the top edge as a thin line
      map.wrapT = THREE.ClampToEdgeWrapping;
      var mat = new MeshLambertMaterial({
        map: map,
        side: THREE.DoubleSide,
      });
      // the residential boards are solid, the chain-link, the slums' broken boards and every hole are cut
      if (tex != TEX_WOOD)
        mat.alphaTest = CUT;
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.name = name;
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// one fence cell's panel: across the cell's middle, parallel to its one street side, the image
// mapped 0..1 across the cell: a fence's painted post stands mid-panel and its lattice wraps into the
// next cell's, a hole's posts stand on the cell edges. v maps the image's height onto the fence's
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
      if (alongX)
        MeshBufTools.quad(b, [a0, 0, p], [a1, 0, p], [a1, tall, p], [a0, tall, p],
          [0, 0, 1, 0, 1, 1, 0, 1]);
      else
        MeshBufTools.quad(b, [p, 0, a1], [p, 0, a0], [p, tall, a0], [p, tall, a1],
          [1, 0, 0, 0, 0, 1, 1, 1]);
    }

// the mouth cells a fenced alley left open, keyed row * width + col: the plain alley cells of every
// alley group that holds a fence, with no solid object and exactly one street 4-neighbour
// (game.CityAreaGenerator.mouthRuns' test). the fence cells were alley before placeFences flipped
// them, so flooding alley and fence together gives back the generator's group
  public static function openMouths(area:AreaGame):Map<Int, Bool>
    {
      var w = area.width;
      var solid = new Map<Int, Bool>();
      for (o in area.getObjects())
        if (!o.isWalkable())
          solid.set(o.y * w + o.x, true);
      var open = new Map<Int, Bool>();
      var seen = new Map<Int, Bool>();
      for (row in 0...area.height)
        for (col in 0...w)
          {
            if (seen.exists(row * w + col) ||
                !isFence(area.getCellType(col, row)))
              continue;
            // flood the group from this fence
            seen.set(row * w + col, true);
            var queue = [{ x: col, y: row }];
            while (queue.length > 0)
              {
                var pt = queue.pop();
                var t = area.getCellType(pt.x, pt.y);
                var streets = 0;
                for (i in 0...Const.dir4x.length)
                  {
                    var nx = pt.x + Const.dir4x[i];
                    var ny = pt.y + Const.dir4y[i];
                    var nt = area.getCellType(nx, ny);
                    if (isStreet(nt))
                      streets++;
                    if ((nt != Const.TILE_ALLEY && !isFence(nt)) ||
                        seen.exists(ny * w + nx))
                      continue;
                    seen.set(ny * w + nx, true);
                    queue.push({ x: nx, y: ny });
                  }
                if (t == Const.TILE_ALLEY &&
                    streets == 1 &&
                    !solid.exists(pt.y * w + pt.x))
                  open.set(pt.y * w + pt.x, true);
              }
          }
      return open;
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
