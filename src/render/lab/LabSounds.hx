package render.lab;

import game.Game;
import game.AreaGame;
import gen.blocks.LabBlocks;
import gen.lab.LabKinds;
import render.AreaSounds;
import render.RenderConfig;
import render.SoundSources;
import render.facility.FacilityModel.Facility;

// the sounds of the underground lab (sound/lab/*.mp3, see docs/sound-gen.md): a bed per room role
// crossfaded by where the player stands, the vat chamber's going dead with the vats; the machines'
// loops by their gen.lab.LabKinds kind and the corridor's air handling, faded by path distance in
// render.AreaSounds and gated off when the lab's power goes; each vat bubbling until it is purged;
// the sputtering fixtures' buzz; the lift motor idling up its shaft; the lockdown klaxon at every
// doorway once the alarm is up; the room's own events (a drip, a knock in a pipe, a valve venting,
// something striking a containment unit from inside, a cable settling up the shaft, the tannoy's
// chime); and the one-shots the lab's own state changes fire: a vat's purge and its drain, the power
// going, the lift coming down. render.facility.FacilitySounds' shape in the lab's own sounds
class LabSounds
{
  // the beds: the corridor, then one per room role, then the vat chamber after the lab dies
  static var BEDS = [
    'lab/corridor',
    'lab/lobby',
    'lab/vat',
    'lab/workshop',
    'lab/storage',
    'lab/research',
    'lab/dead',
  ];
  static inline var BED_VAT = 2;
  static inline var BED_DEAD = 6;
  // the tannoy's chime, every this many seconds or so, at the beds' level: the facility's PA gap
  static inline var PA_GAP = 180.0;

  // the machine kinds behind each loop and event
  static var PUMP = [ 'reactor', 'pipecapsule', 'upw', 'dialtank', 'switchrack' ];
  static var CRYO = [ 'cryobank', 'coldbank', 'cryopod', 'stasis', 'sr203' ];
  static var SPIN = [ 'centrifuge' ];
  static var INCUBATOR = [ 'incubator', 'embryonic', 'rack8', 'rack6', 'ambertanks', 'canisters',
    'specimencase', 'bioprinter', 'gestation' ];
  static var CONSOLE = [ 'terminal', 'screenwall', 'monitorstack', 'holo', 'bioscreen',
    'brainscan' ];
  static var CAGED = [ 'hatchbox', 'tentacle', 'sheetcage', 'cagecase' ];

  var game:Game;
  // the area this was built for, never game.area: a restart swaps that for the new game's start area
  // while the view still ticks this one under the fade
  var area:AreaGame;
  var loops:AreaSounds;
  // each bed's eased level, 0..1, in BEDS order
  var bed:Array<Float>;
  var paWait:Float;
  // the vats the bubbling and the drips come from. the mission stands them on its first turn, after the
  // area is built, so LabArea hands the rebuilt set over (setVats) and the cell list is refilled IN
  // PLACE: AreaSounds holds that array, and a new AreaSounds would fade every bed in again
  var vats:LabVats.LabVatSet;
  var vatCells:Array<{ col:Int, row:Int }> = [];
  // the state the one-shots fire on the change of: each vat's flag, the lab's death, the lift's descent
  var flushed = new Map<Int, Bool>();
  var wasDead = false;
  var arrived:Bool;
  // the live states the gates read, set each tick by LabArea
  var alarmed = false;
  var dead = false;

  public function new(game:Game, m:Facility, vats:LabVats.LabVatSet, lamps:LabLamps.LabLampSet,
      lift:LabLift.LabLiftSet)
    {
      this.game = game;
      area = game.area;
      // the machines by kind, off their origin cells; the computer desks count as consoles
      var by = new Map<String, Array<{ col:Int, row:Int }>>();
      var desks = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var t = area.getCellType(col, row);
            if (t == Const.TILE_LAB_CONSOLE)
              desks.push({
                col: col,
                row: row,
              });
            var k = LabKinds.kindAt(t);
            if (k == null)
              continue;
            if (!by.exists(k.name))
              by.set(k.name, []);
            by.get(k.name).push({
              col: col,
              row: row,
            });
          }
      function cells(kinds:Array<String>)
        {
          var out = [];
          for (k in kinds)
            if (by.exists(k))
              out = out.concat(by.get(k));
          return out;
        }
      var live = function(_) return !dead;
      setVats(vats);
      var liftCells = (lift.col < 0 ? [] : [{
        col: lift.col,
        row: lift.row,
      }]);
      var buzz = [for (p in lamps.all) if (p.phase != 0) {
        col: p.col,
        row: p.row,
      }];
      loops = new AreaSounds(game, [
        {
          key: 'lab/bubble',
          range: 4,
          cells: vatCells,
          gate: function(i) return !this.vats.roots[i].isFlushed,
        },
        { key: 'lab/cryo', range: 3, cells: cells(CRYO), gate: live },
        { key: 'lab/centrifuge', range: 4, cells: cells(SPIN), gate: live },
        { key: 'lab/incubator', range: 3, cells: cells(INCUBATOR), gate: live },
        { key: 'lab/console', range: 3, cells: cells(CONSOLE).concat(desks), gate: live },
        { key: 'lab/buzz', range: 2, cells: buzz, gate: live },
        // ponytail: the lab has no vent objects, so the air handling breathes from the corridor's
        // strip-light cells, which are spaced along it already
        {
          key: 'lab/vent',
          range: 3,
          cells: [for (p in lamps.corridor) {
            col: p.col,
            row: p.row,
          }],
          gate: live,
        },
        { key: 'lab/lift', range: 4, cells: liftCells },
        {
          key: 'lab/klaxon',
          range: 8,
          cells: [for (d in m.doors) {
            col: d.col,
            row: d.row,
          }],
          gate: function(_) return alarmed,
        },
      ], [
        { key: 'lab/drip', range: 3, gap: 14, cells: vatCells },
        { key: 'lab/knock', range: 5, gap: 30, cells: cells(PUMP) },
        { key: 'lab/hiss', range: 4, gap: 25, cells: cells(PUMP).concat(cells(CRYO)) },
        { key: 'lab/thump', range: 4, gap: 40, cells: cells(CAGED) },
        { key: 'lab/shaft', range: 6, gap: 35, cells: liftCells },
      ]);
      bed = [for (_ in BEDS) 0.0];
      paWait = PA_GAP * Math.random();
      arrived = (lift.t > 0);
      SoundSources.beds = BEDS.copy();
      SoundSources.events = [ 'lab/pa' ];
    }

// the vats as they stand now: the bubbling's and the drips' cells refilled in place, and each new
// vat's flag taken as it is, so one already purged on a load does not fire its purge again
  public function setVats(set:LabVats.LabVatSet):Void
    {
      vats = set;
      vatCells.splice(0, vatCells.length);
      for (v in set.roots)
        {
          vatCells.push({
            col: v.x,
            row: v.y + 1,
          });
          if (!flushed.exists(v.id))
            flushed.set(v.id, v.isFlushed);
        }
    }

// which bed plays at the player's cell: its room's role off the rects the generator saved, the vat
// chamber's dead bed once the lab is, and the corridor's everywhere else (doorways, the corridor)
  function bedAt(pc:Int, pr:Int):Int
    {
      var room = area.generatorInfo.getRoomAt(pc, pr);
      if (room == null)
        return 0;
      return switch (room.role)
        {
          case LabBlocks.ROLE_ENTRANCE: 1;
          case LabBlocks.ROLE_VAT: (dead ? BED_DEAD : BED_VAT);
          case LabBlocks.ROLE_WORKSHOP: 3;
          case LabBlocks.ROLE_STORAGE: 4;
          default: 5;
        }
    }

// per frame: the loops and events, the beds crossfaded over four BASE_MS, the tannoy at the beds'
// summed level, and the one-shots the lab's state changes fire
  public function tick(pc:Int, pr:Int, dtMs:Float, lift:LabLift.LabLiftSet, alarmed:Bool,
      dead:Bool):Void
    {
      this.alarmed = alarmed;
      this.dead = dead;
      loops.tick(pc, pr, dtMs);
      var on = bedAt(pc, pr);
      var kb = Math.min(1, dtMs / (RenderConfig.BASE_MS * 4));
      var sum = 0.0;
      for (i in 0...BEDS.length)
        {
          bed[i] += ((i == on ? 1.0 : 0.0) - bed[i]) * kb;
          sum += bed[i];
          game.scene.sounds.updateLoop(BEDS[i], bed[i], game.config.ambientVolume);
        }
      paWait -= dtMs / 1000;
      if (paWait <= 0)
        {
          paWait = PA_GAP * (0.5 + Math.random());
          if (!dead)
            AreaSounds.once(game, 'lab/pa', Math.min(1, sum));
        }
      // a vat purged: the valve where it stands, and its drain
      for (v in vats.roots)
        {
          if (flushed.get(v.id) == v.isFlushed)
            continue;
          flushed.set(v.id, v.isFlushed);
          if (!v.isFlushed)
            continue;
          for (key in [ 'lab/purge', 'lab/drain' ])
            game.scene.sounds.play(key, {
              x: v.x,
              y: v.y + 1,
              always: true,
            });
        }
      if (dead &&
          !wasDead)
        AreaSounds.once(game, 'lab/powerdown', 1.0);
      wasDead = dead;
      // the car coming down: once, as its descent starts, the take running the length of it
      if (!arrived &&
          lift.t > 0)
        {
          arrived = true;
          game.scene.sounds.play('lab/arrive', {
            x: lift.col,
            y: lift.row,
            always: true,
          });
        }
    }
}
