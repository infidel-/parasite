package render.corp;

import game.Game;
import render.AreaSounds;
import render.RenderConfig;
import render.SoundSources;
import render.facility.FacilityModel.Facility;

// the sounds of a corp floor (sound/corp/*.mp3, see docs/sound-gen.md): the machine loops, faded
// by path distance in render.AreaSounds, and the beds, crossfaded by the room the player stands in
class CorpSounds
{
  // the two beds: the corridor's, and the quieter one inside any room
  static var BEDS = ['ambient-corp', 'corp/room'];

  var game:Game;
  var loops:AreaSounds;
  // the lift's cells, which count as a room for the beds
  var lifts:Array<{ col:Int, row:Int }>;
  // each bed's eased level, 0..1, in BEDS order
  var bed:Array<Float>;

  public function new(game:Game, m:Facility)
    {
      this.game = game;
      var area = game.area;
      var racks = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (m.fit[row][col] == CorpFurniture.FIT_RACK)
            racks.push({ col: col, row: row });
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
      ]);
      bed = [0.0, 0.0];
      SoundSources.beds = BEDS.copy();
    }

// per frame: the machine loops, then the bed — corridor or room by the room rects the generator
// saved (a doorway is in none, so it is corridor; the lift is in none either but counts as a room,
// and the reception, whose counter replaces its front wall, counts as corridor), crossfaded over
// four BASE_MS so a doorway step is a fade, never a cut
  public function tick(pc:Int, pr:Int, dtMs:Float):Void
    {
      loops.tick(pc, pr, dtMs);
      var room = game.area.generatorInfo.getRoomAt(pc, pr);
      var inRoom = ((room != null && room.role != gen.corp.CorpTemp.ROLE_RECEPTION) ||
        Lambda.exists(lifts, function(c) return c.col == pc && c.row == pr));
      var kb = Math.min(1, dtMs / (RenderConfig.BASE_MS * 4));
      for (i in 0...BEDS.length)
        {
          bed[i] += ((inRoom == (i == 1) ? 1.0 : 0.0) - bed[i]) * kb;
          game.scene.sounds.updateLoop(BEDS[i], bed[i], game.config.ambientVolume);
        }
    }
}
