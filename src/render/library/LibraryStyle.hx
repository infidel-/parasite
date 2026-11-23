package render.library;

import game.AreaGame;
import gen.library.LibraryGen;
import render.facility.FacilityModel;
import render.facility.FacilityGeom;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Look;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityModel.Wall;
import render.facility.FacilityStyle;
import render.facility.ShellOpts;

// the university library's look and its shell model: art paths, the warm reading-room rig, the
// lamps, the furniture's heights, and the render.facility shell derivation read through the library's
// own tile ids (Const.TILE_LIB_*, gen.library). Like the lab it is a SHELL KIND: the compound's
// emitters drive it, off a ShellTex naming library art
class LibraryStyle
{
  // the shell (art/textures.json library/*)
  public static inline var FLOOR_PARQUET = 'textures/library/floor-parquet.png';
  public static inline var FLOOR_STONE = 'textures/library/floor-stone.png';
  public static inline var FLOOR_CARPET = 'textures/library/floor-carpet.png';
  // the decor's sheets: sixteen shelf rows of books, two PACK16s of what lies on a table, the wall art
  // PACK16 and the eight posters (art/textures.json library/*)
  public static inline var SHELF_BOOKS = 'textures/library/shelf-books.png';
  public static inline var DESK_BOOKS = 'textures/library/desk-books.png';
  public static inline var DESK_PAPERS = 'textures/library/desk-papers.png';
  public static inline var WALL_ART = 'textures/library/wall-art.png';
  public static inline var POSTERS = 'textures/library/posters.png';
  // the alpha cut of every cut-out sheet's opaque alphaTest material
  public static inline var DECAL_CUT = 0.5;
  public static inline var WALL = 'textures/library/wall-panel.png';
  // the wall head and the outer faces: dark oak, so a wall seen from above reads as joinery
  public static inline var HEAD = 'textures/library/shelf-side.png';

  // the rig: a near-black void round the floor, warm low fill
  public static inline var DARK = 0x070504;
  public static inline var FOG_NEAR = 64.0;
  public static inline var FOG_FAR = 150.0;
  public static inline var AMBIENT = 0x574638;
  public static inline var AMBIENT_I = 7.5;
  public static inline var HEMI_SKY = 0x6b5640;
  public static inline var HEMI_GROUND = 0x1c140e;
  public static inline var HEMI_I = 2.4;

  // the ceiling lamps: warm brass pendants, one every LAMP_SPACING cells over each room and the
  // corridor, jittered off the cell centre and in strength by the cell hash
  public static inline var LAMP_Y = 5.6;
  public static inline var LAMP_MUL = 1.0;
  public static inline var LAMP_MUL_VAR = 0.25;
  public static inline var LAMP_JITTER = 1.2;
  public static inline var LAMP_SPACING = 5;
  public static inline var LAMP_COLOR = 0xffd29a;
  // the archive's: dimmer and cooler, the restricted room is kept dark
  public static inline var LAMP_ARCHIVE = 0xc8b8a0;
  public static inline var LAMP_ARCHIVE_MUL = 0.7;

  // each piece's height, the batch's target (the glbs' own, models-src/library/library_build.py)
  public static inline var CASE_H = 5.0;
  public static inline var TABLE_H = 1.6;
  public static inline var CHAIR_H = 2.3;
  public static inline var COUNTER_H = 2.1;
  public static inline var LECTERN_H = 2.5606;
  public static inline var CATALOGUE_H = 2.7;
  // where the Necronomicon's glb stands off the floor, and its height: built lying on the lectern's
  // sloped board, 0.5882 tall with its lowest point 2.0219 up (models-src/library/decor_build.py), it is
  // drawn at 1.2x so it reads, which scales it about its base's centre and lifts its underside 0.047
  // off the board there (the slope's 0.237 times the 0.2) - so it stands that much lower
  public static inline var BOOK_Y = 1.975;
  public static inline var NECRONOMICON_H = 0.7058;
  // the decor glbs' heights as DRAWN: a size up from decor_build.py's (lamp 1.14, basket 0.85, books
  // 0.48), which at the table's own scale read as specks from the game camera
  public static inline var LAMP_H = 1.8;
  public static inline var BASKET_H = 1.2;
  public static inline var BOOKS_H = 0.72;
  // a bookcase's depth off its wall, the stack's both faces, and the catalogue's, for the contact field
  public static inline var CASE_D = 1.2;
  // a wall bookcase's width: narrower than its cell, so every case along a wall stands apart
  public static inline var CASE_W = 3.4;
  public static inline var STACK_D = 2.4;
  public static inline var STACK_W = 3.98;
  // a bookcase's front face off its recentred glb (its boards stand 0.03 proud, so normalize moves it
  // 0.015 back) and a stack rank's two, half its depth
  public static inline var CASE_FRONT = 0.585;
  // the shelf openings between the boards, floor up, as pairs (library_build.py BOARDS: a board's top,
  // the next one's underside; the plinth under the first, the carcass's head over the last), how far
  // in from each side the books stand, and how far proud of the wood
  public static var SHELVES = [ 0.12, 0.84, 0.919, 1.646, 1.732, 2.506, 2.585, 3.313, 3.399, 4.173,
    4.252, 4.93 ];
  public static inline var SHELF_INSET = 0.1;
  public static inline var BOOKS_PROUD = 0.004;
  public static inline var CATALOGUE_D = 3.4;
  public static inline var CATALOGUE_W = 3.6;
  // the chair's footprint, for its floor pool, and how far off square it is turned at most
  public static inline var CHAIR_W = 1.7;
  public static inline var CHAIR_YAW = 0.1745; // 10 degrees
  // the librarian's elder sign glow (render.Actors.elderSign): its colour and peak opacity, its size,
  // how far off the sprite's centre it sits (a fraction of Sprites.SIZE up the leaned plane: below
  // it, on the bust's chest) and how far proud of it, and its breath in BASE_MS
  public static inline var SIGN_COLOR = 0xffe6a0;
  public static inline var SIGN_OP = 0.55;
  public static inline var SIGN_W = 0.6;
  public static inline var SIGN_UP = -0.37;
  public static inline var SIGN_PROUD = 0.06;
  public static inline var SIGN_PERIOD = 6.0;
  // how far a furniture batch's pieces are drawn round the camera
  public static inline var PIECE_CULL_R = 9.0;

// the shell options for this kind
  public static function shell():ShellOpts
    {
      var floor = [for (_ in 0...FacilityStyle.SURF_SLOTS) (null : String)];
      floor[Surf.CARPET] = FLOOR_CARPET;
      floor[Surf.LIB_HALL] = FLOOR_PARQUET;
      floor[Surf.LIB_STACKS] = FLOOR_PARQUET;
      floor[Surf.LIB_LOBBY] = FLOOR_STONE;
      floor[Surf.LIB_ARCHIVE] = FLOOR_STONE;
      return {
        kind: 'library',
        tex: {
          floor: floor,
          wallOut: WALL,
          wallInto: [for (_ in 0...FacilityStyle.SURF_SLOTS) WALL],
          // no windows, light wells or emitted doors: filled with library art so a stray pane can
          // never fall back to another kind's
          pane: WALL,
          pane2: WALL,
          aspect: 1.0,
          aspect2: 1.0,
          paneHigh: WALL,
          head: HEAD,
          roof: HEAD,
          coping: HEAD,
          shutter: null,
          pocket: null,
          sill: null,
          door: [WALL, WALL, WALL, WALL, WALL],
          circ: Surf.CARPET,
          cable: FacilityStyle.CABLE_TEX,
          elec: FacilityStyle.ELEC_TEX,
          elecScale: 1.0,
          elecTint: 1.0,
          floorTile: [for (_ in 0...FacilityStyle.SURF_SLOTS) (null : Float)],
          hood: HEAD,
        },
        surfOf: surfOf,
        wallOf: wallOf,
        // the stairs' well: the corp's hole (CorpModel.fitOf), cut through the lobby floor
        fitOf: function(t:Int) return (t == Const.TILE_LIB_WELL ? FacilityModel.FIT_HOLE : 0),
        tableOf: function(t:Int) return false,
        wallIn: FacilityStyle.WALL_T,
        hangars: false,
        hangarH: FacilityStyle.WALL_H,
        deck: false,
        parapet: false,
      };
    }

// build the model from an area's saved cells; a furniture cell takes its room's floor, by role
  public static function fromArea(area:AreaGame):Facility
    {
      var m = FacilityModel.fromArea(area, null, shell());
      doorways(m, area);
      for (r in m.rooms)
        {
          var s = roleSurf(r.role);
          for (row in r.y1...r.y2 + 1)
            for (col in r.x1...r.x2 + 1)
              if (FacilityModel.inside(m, col, row) &&
                  area.getCellType(col, row) >= Const.TILE_LIB_BOOKCASE)
                m.surf[row][col] = s;
        }
      return m;
    }

// every door cell a DOORWAY with no leaves: the floor splits at the wall line (FacilityGeom.floorStrips),
// so the corridor's carpet stops at the wall instead of running a margin into the room, and the opening
// takes a lintel and its jambs. No objects.Door stands in one, so nothing else marks them
  static function doorways(m:Facility, area:AreaGame):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (area.getCellType(col, row) == Const.TILE_LIB_DOOR)
            m.door[row][col] = true;
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (m.door[row][col])
            m.doors.push({
              col: col,
              row: row,
              alongX: (FacilityGeom.carries(m, col - 1, row) &&
                FacilityGeom.carries(m, col + 1, row)),
              inDir: 1,
              look: Look.CABINET,
              front: false,
              structure: m.owner[row][col],
            });
    }

// is this a bare library floor tile, nothing standing on it (a doorway is not one)
  public static inline function isFloor(t:Int):Bool
    {
      return t >= Const.TILE_LIB_FLOOR_CORRIDOR &&
        t <= Const.TILE_LIB_FLOOR_ARCHIVE;
    }

// the floor a room of this role is laid in
  public static function roleSurf(role:String):Surf
    {
      return switch (role)
        {
          case LibraryGen.ROLE_HALL: Surf.LIB_HALL;
          case LibraryGen.ROLE_LOBBY: Surf.LIB_LOBBY;
          case LibraryGen.ROLE_STACKS: Surf.LIB_STACKS;
          default: Surf.LIB_ARCHIVE;
        }
    }

// the horizontal surface a library tile id paints: the void none, the stairs' well the lobby's (its
// hole is the fit's), furniture TILE
// until fromArea repaints it in its room's floor
  public static function surfOf(t:Int):Surf
    {
      if (t == Const.TILE_LIB_FLOOR_CORRIDOR ||
          t == Const.TILE_LIB_DOOR)
        return Surf.CARPET;
      if (t == Const.TILE_LIB_FLOOR_HALL)
        return Surf.LIB_HALL;
      if (t == Const.TILE_LIB_FLOOR_LOBBY ||
          t == Const.TILE_LIB_WELL)
        return Surf.LIB_LOBBY;
      if (t == Const.TILE_LIB_FLOOR_STACKS)
        return Surf.LIB_STACKS;
      if (t == Const.TILE_LIB_FLOOR_ARCHIVE)
        return Surf.LIB_ARCHIVE;
      if (t >= Const.TILE_LIB_BOOKCASE &&
          t <= Const.TILE_LIB_CATALOGUE)
        return Surf.TILE;
      return Surf.NONE;
    }

// what a library tile id blocks: only the wall. the void is no wall, or every cell of it would emit
  public static function wallOf(t:Int):Wall
    {
      return (t == Const.TILE_LIB_WALL ? Wall.SOLID : Wall.OPEN);
    }

// a throwaway plate for the warm: a strip of every library floor inside a wall ring
  public static function demo():Facility
    {
      var w = 20;
      var h = 10;
      var m = FacilityModel.blank(w, h, shell());
      var strips = [Surf.LIB_HALL, Surf.LIB_LOBBY, Surf.CARPET, Surf.LIB_ARCHIVE];
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
      FacilityModel.findStructures(m, false);
      return m;
    }
}
