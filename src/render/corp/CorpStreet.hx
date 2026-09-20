package render.corp;

import three.Three;
import citygen.CityConfig;
import citygen.CityGen;
import citygen.CityModel.City;
import citygen.CityModel.Tile;
import citygen.CityProfile.Profiles;
import render.Textures;
import render.facility.FacilityGeom;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// what went down there, for __corp()
typedef CorpStreetSet = {
  var group:Group;      // everything, parented at y = STREET_Y so one transform moves the lot
  var city:City;        // the model, handed to Area3D.city() so the crowd and the game can read it
  var road:Int;         // quads
  var walk:Int;
  var blocks:Int;       // street buildings actually built
  var walls:Int;        // and their wall quads
};

// the city street 114 units under the floor plate.
//
// A REAL citygen CITY AT LOW LOD. The MODEL is the real thing — `CityGen.generate` with the
// downtown profile off a seed derived from the area id, so the block structure, the road hierarchy,
// the dead ends and the building footprints down there are a city and not a pattern, and they come
// back identical on every rebuild with nothing persisted. What is LOW is the rendering: render
// .World runs eleven passes and lands a city area in the hundreds of draw calls, and the nearest
// thing here is 114 units away and mostly roof. So this emits FOUR merged meshes off that model
// instead of running those passes, which is what "low LOD" was always going to have to mean.
//
// WHAT IS DELIBERATELY NOT DOWN THERE, each for a reason that is about the DISTANCE and not about
// the effort: no lawns, no entrances, no wall decals, no roof shadows, no roof props (the roof
// sheet paints its own plant), no kerb (the pavement's slab grid is what separates road from
// footpath at this range), no street lamps (the 12-slot spotlight pool belongs to the office, and
// the podium's own warm panes are what puts light at street level), and no `Check` audit — nobody
// walks this city.
//
// AND NO MASK OF ANY KIND. render.world.VisionMask's rim channel sinks a surface to the fog colour
// at the AREA BORDER, and the border is the tower's own edge — patched, the street would be cut to
// nothing exactly where the player leans over the parapet to look at it. IndoorMask likewise: it is
// keyed on the plate's cells and a street cell is not one of them. Everything here is UNLIT
// (MeshBasicMaterial), for CorpFacade's reason: the plate's lighting rig has nothing to do with a
// road 114 units below it, and a lambert takes the warm shopfronts to nothing. Fog still applies —
// a basic material is fogged like any other — which is what makes the far city dissolve into the
// background colour instead of stopping at a line.
class CorpStreet
{
  static inline var CELL = CityConfig.CELL;

// generate the city and emit it. `id` is the area's, and the seed is derived from it rather than
// stored: the street is a function of which area this is and nothing else.
//
// `cx`/`cz` is the FLOOR PLATE's own centre and the radius is measured from THERE, which is the one
// thing about this that is not obvious and cost a build to find: a corp area is 65-75 by 50-60
// cells while CityConfig.cellToWorld is written against a GRID of 100, so the plate does not sit on
// the world origin at all — it sits off in the -x/-z quadrant. A disc centred on the origin is a
// disc of city that is not under the tower, and from the plate's west edge there was simply
// nothing below
  public static function build(scene:Scene, id:Int, cx0:Float, cz0:Float):CorpStreetSet
    {
      var city = CityGen.generate(seed(id),
        Profiles.forArea(_AreaType.AREA_CITY_HIGH));
      var group = new Group();
      group.position.y = CorpStyle.STREET_Y;
      var road = MeshBufTools.make();
      var walk = MeshBufTools.make();
      var roof = MeshBufTools.make();
      var wall = MeshBufTools.make();
      var half = (CityConfig.GRID * CELL) / 2;
      var r2 = CorpStyle.STREET_RADIUS * CorpStyle.STREET_RADIUS;
      var nRoad = 0;
      var nWalk = 0;
      for (row in 0...CityConfig.GRID)
        for (col in 0...CityConfig.GRID)
          {
            var t = city.tiles[row][col];
            if (t == Tile.Building)
              continue;
            var x0 = col * CELL - half;
            var z0 = row * CELL - half;
            // the RADIUS is measured on the cell centre, which is the whole filter: the tower sits
            // at the grid's own centre, so this is a disc of city under it and everything else is
            // past the fog
            var cx = x0 + CELL / 2 - cx0;
            var cz = z0 + CELL / 2 - cz0;
            if (cx * cx + cz * cz > r2)
              continue;
            if (t == Tile.Walkway)
              {
                FacilityGeom.cap(walk, x0, x0 + CELL, z0, z0 + CELL, 0.0, CorpStyle.STREET_TILE);
                nWalk++;
                continue;
              }
            FacilityGeom.cap(road, x0, x0 + CELL, z0, z0 + CELL, 0.0, CorpStyle.STREET_TILE);
            nRoad++;
          }
      var blocks = 0;
      var list:Array<citygen.CityModel.Building> = city.buildings;
      for (b in list)
        {
          var x0 = b.col * CELL - half;
          var z0 = b.row * CELL - half;
          var x1 = x0 + b.w * CELL;
          var z1 = z0 + b.d * CELL;
          var cx = (x0 + x1) / 2 - cx0;
          var cz = (z0 + z1) / 2 - cz0;
          if (cx * cx + cz * cz > r2)
            continue;
          // CAPPED, and it is not cosmetic: the plate is at 0 and the street at -114, so a
          // downtown tower taller than that would come up THROUGH the floor the player is
          // standing on. The profile's own maximum is well under it, but the cap is what makes
          // that a guarantee rather than an observation about today's numbers
          var h = (b.h > CorpStyle.STREET_MAX_H ? CorpStyle.STREET_MAX_H : b.h);
          for (dir in 0...4)
            FacilityGeom.face(wall, x0, x1, z0, z1, dir, 0.0, h, CorpStyle.PODIUM_TILE);
          FacilityGeom.cap(roof, x0, x1, z0, z1, h, CorpStyle.STREET_TILE);
          blocks++;
        }
      add(group, road, CorpStyle.STREET_ASPHALT);
      add(group, walk, CorpStyle.STREET_PAVEMENT);
      add(group, roof, CorpStyle.STREET_ROOF);
      add(group, wall, CorpStyle.STREET_PODIUM);
      scene.add(group);
      return {
        group: group,
        city: city,
        road: nRoad,
        walk: nWalk,
        blocks: blocks,
        walls: Std.int(wall.idx.length / 6),
      };
    }

// the street's seed, off the area id. a plain scramble rather than the id itself, so two adjacent
// corp areas do not get two cities that differ only in their low bits
  public static inline function seed(id:Int):Int
    {
      return render.facility.FacilityModel.mix(id * 2654435 + 12345);
    }

// one merged UNLIT mesh into the street group
  static function add(group:Group, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), new MeshBasicMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: THREE.FrontSide,
      }));
      mesh.receiveShadow = false;
      mesh.castShadow = false;
      group.add(mesh);
    }
}
