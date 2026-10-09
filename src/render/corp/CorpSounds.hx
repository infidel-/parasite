package render.corp;

import game.Game;
import objects.Door;
import render.RenderConfig;
import render.SoundSources;
import render.facility.FacilityModel.Facility;

// the looping machine sounds of a corp floor (sound/corp/*.mp3, see docs/sound-gen.md). each kind
// fades with the PATH distance from the player to its nearest source, searched through cells that
// pass sound — so a wall or a closed door between them silences it, and an open doorway around a
// corner lets it through at the length of the way round
class CorpSounds
{
  // the path search window: the longest range below
  static inline var R = 5;
  static inline var FAR = 1e9;

  // each kind's sound key and the path distance, in cells, at which it falls silent
  static var KINDS:Array<{ key:String, range:Float }> = [
    { key: 'corp/rack', range: 5 },
    { key: 'corp/elevator', range: 4 },
    { key: 'corp/vent', range: 3 },
    { key: 'corp/vending', range: 3 },
    { key: 'corp/cctv', range: 3 },
    { key: 'corp/cooler', range: 2 },
  ];

  // the two beds: the corridor's, and the quieter one inside any room
  static var BEDS = ['ambient-corp', 'corp/room'];

  var game:Game;
  // each bed's eased level, 0..1, in BEDS order
  var bed:Array<Float>;
  // source cells per kind, in KINDS order
  var sources:Array<Array<{ col:Int, row:Int }>>;
  // the floor's doors by cell (row * area width + col): a door object never moves, only opens
  var doors:Map<Int, Door>;
  // each kind's eased level, 0..1
  var level:Array<Float>;
  // path distance per window cell, the player at the centre
  var dist:Array<Float>;

  public function new(game:Game, m:Facility)
    {
      this.game = game;
      var area = game.area;
      var racks = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (m.fit[row][col] == CorpFurniture.FIT_RACK)
            racks.push({ col: col, row: row });
      var lifts = [];
      var vents = [];
      doors = new Map();
      for (o in area.getObjects())
        switch (o.type)
          {
            case 'elevator':
              lifts.push({ col: o.x, row: o.y });
            case 'vent':
              vents.push({ col: o.x, row: o.y });
            case 'door':
              doors[o.y * area.width + o.x] = cast(o, Door);
            default:
          }
      sources = [
        racks,
        lifts,
        vents,
        CorpDeco.cells(area, CorpDeco.K_VENDING),
        CorpSecurity.videoCells(m),
        CorpDeco.cells(area, CorpDeco.K_COOLER),
      ];
      for (i in 0...KINDS.length)
        SoundSources.put(KINDS[i].key, sources[i], KINDS[i].range);
      level = [for (_ in KINDS) 0.0];
      bed = [0.0, 0.0];
      SoundSources.beds = BEDS.copy();
      dist = [for (_ in 0...(2 * R + 1) * (2 * R + 1)) FAR];
    }

// does sound pass this cell: see-through masonry (glass included) with no CLOSED door in it.
// a glass door is see-through shut, which is why the door is asked on its own
  function passes(col:Int, row:Int):Bool
    {
      if (!game.area.canSeeThrough(col, row))
        return false;
      var d = doors[row * game.area.width + col];
      return (d == null || d.isOpen);
    }

// fill `dist` with the path distance from the player's cell to every cell of the window: 8-way,
// a diagonal 1.41 and never cut past a blocked corner, pruned at R
  function search(pc:Int, pr:Int):Void
    {
      var n = 2 * R + 1;
      for (i in 0...dist.length)
        dist[i] = FAR;
      dist[R * n + R] = 0;
      var queue = [R * n + R];
      var qi = 0;
      while (qi < queue.length)
        {
          var i = queue[qi];
          qi++;
          var lc = i % n;
          var lr = Std.int(i / n);
          for (dr in -1...2)
            for (dc in -1...2)
              {
                var c = lc + dc;
                var r = lr + dr;
                if ((dc == 0 && dr == 0) ||
                    c < 0 ||
                    r < 0 ||
                    c >= n ||
                    r >= n ||
                    !passes(pc - R + c, pr - R + r))
                  continue;
                // a diagonal needs both of its orthogonal cells open, or it slips through a wall corner
                if (dc != 0 &&
                    dr != 0 &&
                    (!passes(pc - R + lc + dc, pr - R + lr) ||
                    !passes(pc - R + lc, pr - R + lr + dr)))
                  continue;
                var d = dist[i] + (dc != 0 && dr != 0 ? 1.4142 : 1.0);
                if (d > R ||
                    d >= dist[r * n + c])
                  continue;
                dist[r * n + c] = d;
                queue.push(r * n + c);
              }
        }
    }

// path distance to a source's FACE: its own cell when sound passes it (a cooler, a vending
// machine — the player can stand there), else the passable cells around it (a rack is solid, and
// the floor in front of it is as close as the player gets). either way the nearest point is 0
  function reach(pc:Int, pr:Int, s:{ col:Int, row:Int }):Float
    {
      var n = 2 * R + 1;
      var own = passes(s.col, s.row);
      var best = FAR;
      for (dr in -1...2)
        for (dc in -1...2)
          {
            var c = s.col + dc - pc + R;
            var r = s.row + dr - pr + R;
            if ((own && (dc != 0 || dr != 0)) ||
                c < 0 ||
                r < 0 ||
                c >= n ||
                r >= n)
              continue;
            if (dist[r * n + c] < best)
              best = dist[r * n + c];
          }
      return best;
    }

// per frame: search from the player's cell, aim each kind at full at the nearest source's face and
// at silence at its range — squared, (1 - d/range)^2, so one step off a 3-cell source is already
// -7 dB and not -3.5 — and ease the level there over two BASE_MS so a step or
// a door closing fades rather than cuts. raw dtMs: like the fire loop, sound is not an animation
// ponytail: no panning and no partial muffling, a wall is all or nothing; upgrade by keeping a
// fraction of the level when the only path is through a closed door
  public function tick(pc:Int, pr:Int, dtMs:Float):Void
    {
      search(pc, pr);
      var k = Math.min(1, dtMs / (RenderConfig.BASE_MS * 2));
      for (i in 0...KINDS.length)
        {
          var d = FAR;
          for (s in sources[i])
            d = Math.min(d, reach(pc, pr, s));
          var range = KINDS[i].range;
          var aim = Math.pow(Math.max(0, 1 - d / range), 2);
          level[i] += (aim - level[i]) * k;
          game.scene.sounds.updateLoop(KINDS[i].key, level[i], game.config.ambientVolume);
        }
      // the bed: corridor or room by the room rects the generator saved (a doorway is in none, so
      // it is corridor; the lift is in none either but counts as a room, and the reception, whose
      // counter replaces its front wall, counts as corridor), crossfaded over four BASE_MS so a
      // doorway step is a fade, never a cut
      var room = game.area.generatorInfo.getRoomAt(pc, pr);
      var inRoom = ((room != null && room.role != gen.corp.CorpTemp.ROLE_RECEPTION) ||
        Lambda.exists(sources[1], function(c) return c.col == pc && c.row == pr));
      var kb = Math.min(1, dtMs / (RenderConfig.BASE_MS * 4));
      for (i in 0...BEDS.length)
        {
          bed[i] += ((inRoom == (i == 1) ? 1.0 : 0.0) - bed[i]) * kb;
          game.scene.sounds.updateLoop(BEDS[i], bed[i], game.config.ambientVolume);
        }
    }
}
