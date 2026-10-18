package render.lab;

import game.AreaGame;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityModel.Wall;

// the underground lab as a render.facility shell model: the compound's own derivation off the saved
// grid (structures, walls, doorways), with the lab's tile ids read through LabStyle.shell.
//
// what the shared derivation cannot know is the floor UNDER a piece of furniture — gen.lab writes a
// furniture or machine id over the room's floor tile, and the id names the furniture and not the
// room — so that comes back off the room records, by the role gen.lab dealt each one
class LabModel
{
// build the model from an area's saved cells
  public static function fromArea(area:AreaGame):Facility
    {
      var m = FacilityModel.fromArea(area, null, LabStyle.shell());
      // AFTER the shared pass and over whatever it chose: its themeRooms spreads the last themed
      // surface it meets in a room's rect over that room's TILE cells, and in the vat chamber that
      // can be a vat pad
      for (r in m.rooms)
        {
          var s = roleSurf(r.role);
          for (row in r.y1...r.y2 + 1)
            for (col in r.x1...r.x2 + 1)
              if (FacilityModel.inside(m, col, row) &&
                  area.getCellType(col, row) >= Const.OFFSET_ROW23)
                {
                  m.surf[row][col] = s;
                  // taken, for the electrical render.facility.FacilityCable lays in the rooms
                  m.deco[row][col] = _FittingKind.FIT_LAB + 1;
                }
        }
      return m;
    }

// the floor a room of this role is laid in
  public static function roleSurf(role:String):Surf
    {
      return switch (role)
        {
          case gen.blocks.LabBlocks.ROLE_ENTRANCE: Surf.LAB_ENTRANCE;
          case gen.blocks.LabBlocks.ROLE_VAT: Surf.LAB_VAT;
          case gen.blocks.LabBlocks.ROLE_WORKSHOP: Surf.LAB_WORKSHOP;
          case gen.blocks.LabBlocks.ROLE_STORAGE: Surf.LAB_STORAGE;
          default: Surf.LAB_RESEARCH;
        }
    }

// the horizontal surface a lab tile id paints. furniture and machines (rows 23 on) come back as
// TILE, which the lab has no art for, and fromArea repaints them in their room's floor
  public static function surfOf(t:Int):Surf
    {
      if (t == Const.TILE_LAB_CORRIDOR ||
          t == Const.TILE_LAB_DOOR)
        return Surf.LINO;
      if (t == Const.TILE_LAB_FLOOR_ENTRANCE)
        return Surf.LAB_ENTRANCE;
      if (t == Const.TILE_LAB_FLOOR_VAT)
        return Surf.LAB_VAT;
      if (t == Const.TILE_LAB_FLOOR_WORKSHOP)
        return Surf.LAB_WORKSHOP;
      if (t == Const.TILE_LAB_FLOOR_STORAGE)
        return Surf.LAB_STORAGE;
      if (t == Const.TILE_LAB_FLOOR_RESEARCH)
        return Surf.LAB_RESEARCH;
      if (t == Const.TILE_LAB_LIFT)
        return Surf.LIFT;
      if (t == Const.TILE_LAB_VAT_PAD)
        return Surf.LAB_PAD;
      if (t >= Const.OFFSET_ROW23)
        return Surf.TILE;
      return Surf.NONE;
    }

// what a lab tile id blocks. the rock is not a wall: it is the void the walls are cut into, capped
// by render.lab.LabGeom, and as a wall every one of its cells would emit faces and a wall head
  public static function wallOf(t:Int):Wall
    {
      return (t == Const.TILE_LAB_WALL ? Wall.SOLID : Wall.OPEN);
    }

// a throwaway plate for the warm (LabWarm): one strip of every lab floor between partitions, a
// two-cell doorway and the bedrock round it, so every shell material this kind owns has geometry
  public static function demo():Facility
    {
      var w = 24;
      var h = 12;
      var m = FacilityModel.blank(w, h, LabStyle.shell());
      var strips = [Surf.LAB_ENTRANCE, Surf.LAB_VAT, Surf.LAB_PAD, Surf.LAB_WORKSHOP,
        Surf.LAB_STORAGE, Surf.LAB_RESEARCH, Surf.LINO];
      for (row in 1...h - 1)
        for (col in 1...w - 1)
          {
            if (row == 1 ||
                row == h - 2 ||
                col == 1 ||
                col == w - 2)
              {
                m.wall[row][col] = Wall.SOLID;
                continue;
              }
            m.surf[row][col] = strips[Std.int((col - 2) * strips.length / (w - 4))];
          }
      // a partition with a two-cell doorway in it, between the first two strips
      for (row in 2...h - 2)
        if (row != 5 &&
            row != 6)
          {
            m.wall[row][5] = Wall.SOLID;
            m.surf[row][5] = Surf.NONE;
          }
      FacilityModel.findStructures(m, false);
      for (row in 5...7)
        {
          m.surf[row][5] = Surf.LINO;
          m.door[row][5] = true;
          m.doors.push({
            col: 5,
            row: row,
            alongX: false,
            inDir: 1,
            look: CABINET,
            front: false,
            structure: 0,
          });
        }
      return m;
    }
}
