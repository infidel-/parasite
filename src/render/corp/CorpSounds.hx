package render.corp;

import game.Game;
import gen.corp.CorpTemp;
import render.AreaSounds;
import render.RenderConfig;
import render.SoundSources;
import render.facility.FacilityModel.Facility;

// the sounds of a corp floor (sound/corp/*.mp3, see docs/sound-gen.md): the machine loops and the
// odd phone or drip, faded by path distance in render.AreaSounds, and the beds, crossfaded by the
// room the player stands in
class CorpSounds
{
  // the beds: the corridor's, the quieter one inside any room, and the two rooms with a tone of
  // their own — the cubicle farm's computers and the washroom's pipes
  static var BEDS = ['ambient-corp', 'corp/room', 'corp/cubicle', 'corp/washroom'];
  static inline var BED_WASHROOM = 3;
  // a toilet flushing somewhere behind the washroom's walls, every this many seconds or so
  static inline var FLUSH_GAP = 80.0;

  var game:Game;
  var loops:AreaSounds;
  // the lift's cells, which count as a room for the beds
  var lifts:Array<{ col:Int, row:Int }>;
  // each bed's eased level, 0..1, in BEDS order
  var bed:Array<Float>;
  // seconds to the next distant flush
  var flushWait:Float;

  public function new(game:Game, m:Facility)
    {
      this.game = game;
      var area = game.area;
      var racks = [];
      var basins = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.fit[row][col] == CorpFurniture.FIT_RACK)
              racks.push({ col: col, row: row });
            // a washroom fixture in a RUN is a basin; one on its own is a WC stall
            if (CorpFurniture.fixture(m, col, row) &&
                CorpFurniture.run(m, col, row))
              basins.push({ col: col, row: row });
          }
      // the plate's outer glazing, not a meeting room's
      var windows = [];
      for (row in 0...area.height)
        for (col in 0...area.width)
          {
            var t = area.getCellType(col, row);
            if (t >= Const.TILE_CORP_WINDOW1 &&
                t <= Const.TILE_CORP_WINDOWV3)
              windows.push({ col: col, row: row });
          }
      // a washroom basin's run carries a tap decoration too: one cell, one chance to drip
      var drips = CorpDeco.cells(area, CorpDeco.K_TAP);
      for (b in basins)
        if (!Lambda.exists(drips, function(c) return c.col == b.col && c.row == b.row))
          drips.push(b);
      lifts = [];
      for (o in area.getObjects())
        if (o.type == 'elevator')
          lifts.push({ col: o.x, row: o.y });
      loops = new AreaSounds(game, [
        { key: 'corp/rack', range: 5, cells: racks },
        { key: 'corp/elevator', range: 4, cells: lifts },
        { key: 'corp/vending', range: 3, cells: CorpDeco.cells(area, CorpDeco.K_VENDING) },
        { key: 'corp/cctv', range: 3, cells: CorpSecurity.videoCells(m) },
        { key: 'corp/cooler', range: 2, cells: CorpDeco.cells(area, CorpDeco.K_COOLER) },
        { key: 'corp/window', range: 2, cells: windows },
        {
          key: 'corp/fridge',
          range: 3,
          cells: CorpDeco.cells(area, CorpDeco.K_FRIDGE),
          duty: { on: 40, off: 60 },
        },
      ], [
        { key: 'corp/phone', range: 4, gap: 60, cells: CorpClutter.phoneCells(m, area) },
        { key: 'corp/drip', range: 2, gap: 16, cells: drips },
      ]);
      bed = [for (_ in BEDS) 0.0];
      flushWait = FLUSH_GAP * Math.random();
      SoundSources.beds = BEDS.copy();
      SoundSources.events = ['corp/flush'];
    }

// which bed plays at the player's cell, by the room rects the generator saved: a doorway is in
// none, so it is corridor; the lift is in none either but counts as a room; the reception, whose
// counter replaces its front wall, counts as corridor; and a room with a role older saves never
// wrote takes the plain room's
  function bedAt(pc:Int, pr:Int):Int
    {
      if (Lambda.exists(lifts, function(c) return c.col == pc && c.row == pr))
        return 1;
      var room = game.area.generatorInfo.getRoomAt(pc, pr);
      if (room == null ||
          room.role == CorpTemp.ROLE_RECEPTION)
        return 0;
      return (room.role == CorpTemp.ROLE_CUBICLE ? 2 :
        (room.role == CorpTemp.ROLE_TOILET ? BED_WASHROOM : 1));
    }

// per frame: the loops and events, then the beds crossfaded over four BASE_MS so a doorway step is
// a fade, never a cut, then the washroom's distant flush, which has no source — it is the bed's own
// event, at the bed's level
  public function tick(pc:Int, pr:Int, dtMs:Float):Void
    {
      loops.tick(pc, pr, dtMs);
      var on = bedAt(pc, pr);
      var kb = Math.min(1, dtMs / (RenderConfig.BASE_MS * 4));
      for (i in 0...BEDS.length)
        {
          bed[i] += ((i == on ? 1.0 : 0.0) - bed[i]) * kb;
          game.scene.sounds.updateLoop(BEDS[i], bed[i], game.config.ambientVolume);
        }
      flushWait -= dtMs / 1000;
      if (flushWait > 0)
        return;
      flushWait = FLUSH_GAP * (0.5 + Math.random());
      if (bed[BED_WASHROOM] > 0.01)
        AreaSounds.once(game, 'corp/flush', bed[BED_WASHROOM]);
    }
}
