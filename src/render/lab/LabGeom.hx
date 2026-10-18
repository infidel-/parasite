package render.lab;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityModel.Wall;
import render.facility.FacilityStyle;
import render.world.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// the BEDROCK the lab is cut into: one flat cap at the wall head over every rock cell, run-merged a
// row at a time, carried ROCK_MARGIN cells past the area's edge, plus the strip of each wall cell
// its slab leaves on a rock side (FacilityGeom.slab insets a perimeter slab a unit off the rock, and
// that unit would otherwise be a slot of fog colour all the way round every room).
//
// NOT vision-masked, for the roof's reason (FacilityGeom.addDeck): the sweep never reaches a rock
// cell, so masked it would sink to the fog colour everywhere and the rooms would float in a void
// rather than sit in the rock
class LabGeom
{
  static inline var CELL = CityConfig.CELL;

// emit the cap. returns the quad count, for __lab()
  public static function build(scene:Scene, m:Facility):Int
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var y = FacilityStyle.ROOF_Y;
      var t = LabStyle.ROCK_TILE;
      var b = MeshBufTools.make();
      var mg = LabStyle.ROCK_MARGIN;
      // rock runs along each row, margin included
      for (row in -mg...m.h + mg)
        {
          var start = -mg - 1;
          for (col in -mg...m.w + mg + 1)
            {
              var r = (col < m.w + mg && rock(m, col, row));
              if (r &&
                  start < -mg)
                start = col;
              else if (!r &&
                  start >= -mg)
                {
                  FacilityGeom.cap(b, start * CELL - half, col * CELL - half,
                    row * CELL - half, (row + 1) * CELL - half, y, t);
                  start = -mg - 1;
                }
            }
        }
      // and the wall cells' rock-side strips. N and S span the cell, W and E what is left between
      // them, so nothing overlaps; a corner whose two hands are rock is the N or S strip's
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!FacilityModel.isWall(m, col, row))
              continue;
            var s = FacilityGeom.slab(m, col, row);
            var x0 = col * CELL - half;
            var z0 = row * CELL - half;
            if (rock(m, col, row - 1))
              FacilityGeom.cap(b, x0, x0 + CELL, z0, s.z0, y, t);
            if (rock(m, col, row + 1))
              FacilityGeom.cap(b, x0, x0 + CELL, s.z1, z0 + CELL, y, t);
            if (rock(m, col - 1, row))
              FacilityGeom.cap(b, x0, s.x0, s.z0, s.z1, y, t);
            if (rock(m, col + 1, row))
              FacilityGeom.cap(b, s.x1, x0 + CELL, s.z0, s.z1, y, t);
            // the outer corner of an L whose two arms are walls and whose diagonal is rock:
            // FacilityGeom.capTop notches the head there and fills the notch only over indoor floor,
            // so over rock it was a square hole down to the fog. It spans from this cell's corner to
            // where the two arm cells' own slabs stop short of the rock
            for (dz in [-1, 1])
              for (dx in [-1, 1])
                {
                  if (!FacilityModel.isWall(m, col + dx, row) ||
                      !FacilityModel.isWall(m, col, row + dz) ||
                      !rock(m, col + dx, row + dz))
                    continue;
                  var sv = FacilityGeom.slab(m, col, row + dz);
                  var sh = FacilityGeom.slab(m, col + dx, row);
                  var xa = (dx < 0 ? x0 : sv.x1), xb = (dx < 0 ? sv.x0 : x0 + CELL);
                  var za = (dz < 0 ? z0 : sh.z1), zb = (dz < 0 ? sh.z0 : z0 + CELL);
                  if (xb > xa &&
                      zb > za)
                    FacilityGeom.cap(b, xa, xb, za, zb, y, t);
                }
          }
      if (b.idx.length == 0)
        return 0;
      var mesh = new Mesh(FacilityGeom.geom(b), new MeshLambertMaterial({
        map: Textures.loadTexture(LabStyle.ROCK, 'wall', 1),
        side: THREE.FrontSide,
      }));
      mesh.name = 'lab rock';
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
      return Std.int(b.idx.length / 6);
    }

// is this cell bedrock: off the grid, or neither floor, wall nor doorway
  static function rock(m:Facility, col:Int, row:Int):Bool
    {
      return !FacilityModel.inside(m, col, row) ||
        (m.surf[row][col] == Surf.NONE &&
         m.wall[row][col] == Wall.OPEN &&
         !m.door[row][col]);
    }
}
