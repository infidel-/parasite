package render.facility;

import game.Game;
import gen.facility.FacilityTemp;
import render.AreaSounds;
import render.RenderConfig;
import render.SoundSources;
import render.facility.FacilityModel;

// the sounds of a research compound (sound/facility/*.mp3, see docs/sound-gen.md): the machine
// loops and the odd drip, gurgle, bird or passing car, faded by path distance in render.AreaSounds,
// and the beds, crossfaded by where the player stands — the clone of render.corp.CorpSounds, with
// the outdoors split off the corridor
class FacilitySounds
{
  // the beds: the corridor's, every room's lab tone, the washroom's pipes, the hangar's shed, and
  // the two outdoors — the park's leaves and the asphalt's wind and road
  static var BEDS = [
    'ambient-facility',
    'facility/lab',
    'facility/washroom',
    'facility/hangar',
    'facility/park',
    'facility/exterior',
  ];
  static inline var BED_WASHROOM = 2;
  // the beds under a roof, which carry the PA
  static inline var INDOOR = 4;
  static inline var BED_PARK = 4;
  static inline var BED_EXTERIOR = 5;
  // a toilet flushing behind the washroom's walls, and the tannoy, every this many seconds or so
  static inline var FLUSH_GAP = 80.0;
  static inline var PA_GAP = 180.0;

  var game:Game;
  var m:Facility;
  var loops:AreaSounds;
  // each bed's eased level, 0..1, in BEDS order
  var bed:Array<Float>;
  // seconds to the next distant flush and the next announcement
  var flushWait:Float;
  var paWait:Float;

  public function new(game:Game, m:Facility)
    {
      this.game = game;
      this.m = m;
      var area = game.area;
      // the fitted kinds off the model's grid, the sinks off theirs, the trees and the road off
      // the tiles
      var racks = [];
      var machines = [];
      var generators = [];
      var drips = [];
      var drains = [];
      var trees = [];
      var road = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var c = { col: col, row: row };
            var k = m.deco[row][col] - 1;
            if (k == _FittingKind.FIT_RACK ||
                k == _FittingKind.FIT_RACK_LOW)
              racks.push(c);
            else if (k == _FittingKind.FIT_MACHINE ||
                k == _FittingKind.FIT_ANALYSER)
              machines.push(c);
            else if (k == _FittingKind.FIT_GENERATOR)
              generators.push(c);
            if (k == _FittingKind.FIT_BASIN ||
                m.tableSink[row][col])
              drips.push(c);
            if (m.drain[row][col])
              drains.push(c);
            var t = area.getCellType(col, row);
            if (t >= Const.TILE_TREE1 &&
                t < Const.TILE_BUSH)
              trees.push(c);
            if (m.surf[row][col] == Surf.ROAD)
              road.push(c);
          }
      // the lab case is one kind for four frames; the fridge (8/0) and the freezer (8/1) hum
      var fridges = [];
      for (o in area.getObjects())
        if (o.type == 'decoration' &&
            o.imageRow == 8 &&
            o.imageCol < 2)
          fridges.push({ col: o.x, row: o.y });
      loops = new AreaSounds(game, [
        // an objects.Vent stands on a WALL cell, so it is heard from the floor either side of it
        {
          key: 'facility/vent',
          range: 3,
          cells: [for (o in area.getObjects()) if (o.type == 'vent') { col: o.x, row: o.y }],
        },
        { key: 'corp/rack', range: 5, cells: racks },
        { key: 'facility/machine', range: 3, cells: machines },
        { key: 'facility/generator', range: 6, cells: generators },
        {
          key: 'corp/fridge',
          range: 3,
          cells: fridges,
          duty: { on: 40, off: 60 },
        },
      ], [
        { key: 'corp/drip', range: 2, gap: 16, cells: drips },
        { key: 'facility/drain', range: 2, gap: 40, cells: drains },
        { key: 'facility/birds', range: 6, gap: 20, cells: trees },
        { key: 'facility/car', range: 8, gap: 45, cells: road },
      ]);
      bed = [for (_ in BEDS) 0.0];
      flushWait = FLUSH_GAP * Math.random();
      paWait = PA_GAP * Math.random();
      SoundSources.beds = BEDS.copy();
      SoundSources.events = ['corp/flush', 'facility/pa'];
    }

// which bed plays at the player's cell: the hangar by its structure (it is a room rect with no
// role, like a lab), then the room rects the generator saved — a washroom by its role, every other
// room the lab's tone, offices and stores included — then a doorway or a corridor, which is in no
// rect, and the outdoors split by surface into the park's grass and everything else
  function bedAt(pc:Int, pr:Int):Int
    {
      if (FacilityModel.inHangar(m, pc, pr))
        return 3;
      var room = game.area.generatorInfo.getRoomAt(pc, pr);
      if (room != null)
        return (room.role == FacilityTemp.ROLE_TOILET ? BED_WASHROOM : 1);
      if (FacilityModel.isIndoor(m, pc, pr))
        return 0;
      return (m.surf[pr][pc] == Surf.GRASS ? BED_PARK : BED_EXTERIOR);
    }

// per frame: the loops and events, then the beds crossfaded over four BASE_MS so a doorway step is
// a fade, never a cut, then the two sourceless events — the washroom's flush at that bed's level
// and the tannoy at the summed level of the beds under a roof, so neither is heard outdoors
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
      var sec = dtMs / 1000;
      flushWait -= sec;
      if (flushWait <= 0)
        {
          flushWait = FLUSH_GAP * (0.5 + Math.random());
          if (bed[BED_WASHROOM] > 0.01)
            AreaSounds.once(game, 'corp/flush', bed[BED_WASHROOM]);
        }
      paWait -= sec;
      if (paWait <= 0)
        {
          paWait = PA_GAP * (0.5 + Math.random());
          var indoor = 0.0;
          for (i in 0...INDOOR)
            indoor += bed[i];
          if (indoor > 0.01)
            AreaSounds.once(game, 'facility/pa', Math.min(1, indoor));
        }
    }
}
