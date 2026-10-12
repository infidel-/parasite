package render.military;

import game.Game;
import gen.facility.FacilityTemp;
import map.Terrain;
import render.AreaSounds;
import render.RenderConfig;
import render.SoundSources;
import render.facility.FacilityModel;

// the sounds of a military base (sound/military/*.mp3, see docs/sound-gen.md): the barracks vents,
// the wind in the fence, an engine idling in the motor pool, a radio left on by the safe and the
// hangar's generator, faded by path distance in render.AreaSounds, and a truck passing on the road;
// the beds crossfaded by where the player stands, the margin outside the fence wearing its terrain
// band's own wild bed and the road the wilderness highway's; and the far one-shots no source owns —
// a jet, a helicopter, the range — heard loudest in the open. The latrine and the comms room have
// their own beds and their own one-shots: a tap dripping into a basin, a toilet flushing behind the
// partitions, a receiver breaking squelch on a rack. render.facility.FacilitySounds trimmed to what a
// base has, in its own sounds, and played INSTEAD of it
class MilitarySounds
{
  // the beds: a building's corridors, the hangar's shed, the yard inside the fence, the road past the
  // gate (the wilderness highway's), the latrine's pipes, the comms room's sets, any other room
  // (quieter than the corridor, asked for), and the margin outside the fence (the band's, appended in
  // `new`)
  static var BEDS = [
    'military/indoor',
    'military/hangar',
    'military/yard',
    'wild/road',
    'military/latrine',
    'military/comms',
    'military/room',
  ];
  static inline var BED_HANGAR = 1;
  static inline var BED_YARD = 2;
  static inline var BED_ROAD = 3;
  static inline var BED_LATRINE = 4;
  static inline var BED_COMMS = 5;
  static inline var BED_ROOM = 6;
  static inline var BED_MARGIN = 7;
  // a toilet flushing behind the latrine's partitions, every this many seconds or so: the facility
  // washroom's gap
  static inline var FLUSH_GAP = 80.0;
  // how far either side of the road's centreline its bed plays, in cells: render.wild.WildSounds'
  static inline var ROAD_REACH = 4.0;
  // how loud a far one-shot is under a roof, against 1 in the open
  static inline var FAR_INDOOR = 0.4;

  var game:Game;
  var m:Facility;
  var loops:AreaSounds;
  // the beds in play, BEDS plus the margin's band bed
  var beds:Array<String>;
  // each bed's eased level, 0..1, in `beds` order
  var bed:Array<Float>;
  // the one-shots with no source, each with its mean gap and seconds to its next roll
  var far:Array<{ key:String, gap:Float, wait:Float }>;
  // the road's centreline row
  var roadRow:Float;
  // seconds to the next flush
  var flushWait:Float;

  public function new(game:Game, m:Facility)
    {
      this.game = game;
      this.m = m;
      var area = game.area;
      // the sources off the saved grid and the model's fittings
      var generators = [];
      var fence = [];
      var idle = [];
      var road = [];
      var sinks = [];
      var racks = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var c = { col: col, row: row };
            var t = area.getCellType(col, row);
            if (m.deco[row][col] - 1 == _FittingKind.FIT_GENERATOR)
              generators.push(c);
            if (t == Const.TILE_MIL_FENCE ||
                t == Const.TILE_MIL_FENCE_TORN)
              fence.push(c);
            else if (t == Const.TILE_MIL_HUMVEE)
              idle.push(c);
            else if (t == Const.TILE_MIL_SINKS ||
                t == Const.TILE_MIL_SHOWER)
              sinks.push(c);
            else if (t == Const.TILE_MIL_RADIO_RACK)
              racks.push(c);
            if (m.surf[row][col] == Surf.ROAD)
              road.push(c);
          }
      loops = new AreaSounds(game, [
        {
          key: 'military/vent',
          range: 3,
          cells: [for (o in area.getObjects()) if (o.type == 'vent') { col: o.x, row: o.y }],
        },
        { key: 'military/generator', range: 6, cells: generators },
        { key: 'military/fence', range: 2, cells: fence },
        // ponytail: every humvee idles, one engine sound however many are parked
        { key: 'military/idle', range: 5, cells: idle },
        {
          key: 'military/radio',
          range: 4,
          cells: [for (o in area.getObjects()) if (o.type == 'safe') { col: o.x, row: o.y }],
        },
      ], [
        { key: 'military/truck', range: 8, gap: 45, cells: road },
        { key: 'military/drip', range: 2, gap: 16, cells: sinks },
        { key: 'military/squelch', range: 4, gap: 25, cells: racks },
      ]);
      var lo = m.h;
      var hi = -1;
      for (c in road)
        {
          lo = Std.int(Math.min(lo, c.row));
          hi = Std.int(Math.max(hi, c.row));
        }
      roadRow = (lo + hi) / 2;
      var band = switch (Terrain.bandAtArea(game.region.mapSeed, area.x, area.y))
        {
          case TERRAIN_FOREST: 'wild/forest';
          case TERRAIN_MOUNTAIN: 'wild/mountain';
          default: 'wild/plains';
        };
      beds = BEDS.concat([ band ]);
      bed = [for (_ in beds) 0.0];
      far = [
        {
          key: 'military/jet',
          gap: 150,
          wait: 0,
        },
        {
          key: 'city/helicopter',
          gap: 200,
          wait: 0,
        },
        {
          key: 'military/range',
          gap: 120,
          wait: 0,
        },
      ];
      for (f in far)
        f.wait = f.gap * Math.random();
      flushWait = FLUSH_GAP * Math.random();
      SoundSources.beds = beds.copy();
      SoundSources.events = [for (f in far) f.key].concat([ 'military/flush' ]);
    }

// which bed plays at the player's cell: the hangar by its structure, the latrine and the comms room by
// the room rects the generator saved, any other room rect under a roof the room bed, the rest of the
// roof (corridors, doorways) the building's, and the open split by the fence, the outside again by the
// road
  function bedAt(pc:Int, pr:Int):Int
    {
      if (FacilityModel.inHangar(m, pc, pr))
        return BED_HANGAR;
      var room = game.area.generatorInfo.getRoomAt(pc, pr);
      if (room != null &&
          room.role == FacilityTemp.ROLE_LATRINE)
        return BED_LATRINE;
      if (room != null &&
          room.role == FacilityTemp.ROLE_COMMS)
        return BED_COMMS;
      if (FacilityModel.isIndoor(m, pc, pr))
        return (room != null ? BED_ROOM : 0);
      if (!game.area.isOutsideBase(pc, pr))
        return BED_YARD;
      return (Math.abs(pr - roadRow) <= ROAD_REACH ? BED_ROAD : BED_MARGIN);
    }

// per frame: the loops and events, the beds crossfaded over four BASE_MS, the latrine's flush at its
// bed's level, so it is heard in the latrine and nowhere else, then the far one-shots at the open beds'
// level with a floor under a roof
  public function tick(pc:Int, pr:Int, dtMs:Float):Void
    {
      loops.tick(pc, pr, dtMs);
      var on = bedAt(pc, pr);
      var kb = Math.min(1, dtMs / (RenderConfig.BASE_MS * 4));
      for (i in 0...beds.length)
        {
          bed[i] += ((i == on ? 1.0 : 0.0) - bed[i]) * kb;
          game.scene.sounds.updateLoop(beds[i], bed[i], game.config.ambientVolume);
        }
      flushWait -= dtMs / 1000;
      if (flushWait <= 0)
        {
          flushWait = FLUSH_GAP * (0.5 + Math.random());
          if (bed[BED_LATRINE] > 0.01)
            AreaSounds.once(game, 'military/flush', bed[BED_LATRINE]);
        }
      var open = bed[BED_YARD] + bed[BED_ROAD] + bed[BED_MARGIN];
      for (f in far)
        {
          f.wait -= dtMs / 1000;
          if (f.wait > 0)
            continue;
          f.wait = f.gap * (0.5 + Math.random());
          AreaSounds.once(game, f.key, FAR_INDOOR + (1 - FAR_INDOOR) * Math.min(1, open));
        }
    }
}
