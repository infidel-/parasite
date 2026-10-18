// the underground lab's machines: every kind, its footprint and the rooms it belongs in
//
// the 2D lab drew about seventy machine sprites as decorations over the tiles. Each is a kind here,
// with the FOOTPRINT THE THING HAS IN 3D rather than the 2D sprite's: a sprite's height is drawn over
// the row above it, so a two-by-two sprite of a cabinet is a cabinet two cells long and one deep.
//
// APPEND ONLY. A kind's index is the saved tile id of its origin cell (Const.TILE_LAB_MACHINE0 +
// index), so reordering this list turns every saved incubator into something else. A kind that goes
// out of use stays in the table and stops being dealt: its rooms list is empty. Fourteen went out
// 2026-10-15 when the machines were rebuilt by hand: half the research bay's kinds (a second empty
// tube, the trolley, four consoles of one look, the scanner, the clamp, the probe, the capsule, the
// robot chair, the booth, the analysis station) and the lobby's incinerator bin.

package gen.lab;

import gen.blocks.LabBlocks.*;

class LabKinds
{
  public static var MACHINES: Array<_LabMachine> = [
    // the clone floor's plant and the research bays' equipment
    m('reactor', 2, 2, false, false, [ ROLE_VAT ]),
    m('screenwall', 2, 1, true, false, [ ROLE_VAT, ROLE_RESEARCH ]),
    m('hatchbox', 2, 1, true, false, [ ROLE_VAT ]),
    m('dialtank', 1, 1, false, false, [ ROLE_VAT, ROLE_WORKSHOP ]),
    m('autopsy', 2, 1, false, false, [ ROLE_RESEARCH ]),
    m('tube', 1, 1, false, false, [ ROLE_VAT, ROLE_RESEARCH ]),
    m('tubeempty', 1, 1, false, false, []),
    m('trolley', 1, 1, false, false, []),
    m('instconsole', 2, 1, true, false, []),
    m('restraint', 1, 1, false, false, [ ROLE_RESEARCH ]),
    m('switchrack', 2, 1, true, false, [ ROLE_VAT, ROLE_WORKSHOP ]),
    m('scanner', 1, 1, false, false, []),
    m('terminal', 2, 1, true, false, [ ROLE_RESEARCH, ROLE_VAT ]),
    m('holo', 2, 1, false, false, [ ROLE_RESEARCH ]),
    m('tubeconsole', 1, 1, true, true, []),
    m('joystick', 2, 1, true, false, []),
    m('monitorstack', 2, 1, true, false, [ ROLE_RESEARCH, ROLE_VAT ]),
    m('pipecapsule', 2, 1, true, false, [ ROLE_VAT ]),
    m('powerbox', 2, 1, true, false, [ ROLE_WORKSHOP, ROLE_VAT ]),
    m('clamp', 2, 2, false, false, []),
    m('leverbox', 1, 1, true, true, [ ROLE_WORKSHOP ]),
    m('tentacle', 2, 1, false, false, [ ROLE_VAT ]),
    m('bioscreen', 2, 1, true, false, [ ROLE_RESEARCH, ROLE_VAT ]),
    m('cryopod', 2, 1, false, false, [ ROLE_RESEARCH, ROLE_VAT ]),
    m('probe', 1, 1, false, false, []),
    m('stasis', 1, 1, false, false, [ ROLE_RESEARCH, ROLE_VAT ]),
    m('capsule', 2, 1, false, false, []),
    m('robochair', 1, 1, false, false, []),
    m('winconsole', 2, 1, true, false, []),
    m('upw', 2, 1, true, false, [ ROLE_VAT, ROLE_WORKSHOP ]),
    m('booth', 2, 2, true, false, []),
    m('incinerator', 2, 1, true, false, [ ROLE_RESEARCH, ROLE_VAT ]),
    m('analysis', 2, 2, false, false, []),
    m('bioprinter', 2, 2, false, false, [ ROLE_RESEARCH ]),
    // the store's cold chain and cabinets
    m('vault', 2, 2, false, false, [ ROLE_STORAGE ]),
    m('specimencase', 3, 1, true, false, [ ROLE_STORAGE, ROLE_RESEARCH ]),
    m('ambertanks', 2, 1, true, false, [ ROLE_RESEARCH, ROLE_STORAGE, ROLE_VAT ]),
    m('processor', 2, 1, true, false, [ ROLE_STORAGE ]),
    m('incubator', 2, 1, true, false, [ ROLE_RESEARCH, ROLE_STORAGE ]),
    m('brainscan', 2, 1, true, false, [ ROLE_RESEARCH ]),
    m('coldbank', 3, 1, true, false, [ ROLE_STORAGE ]),
    m('cryobank', 3, 2, true, false, [ ROLE_STORAGE ]),
    m('centrifuge', 2, 2, false, false, [ ROLE_VAT, ROLE_RESEARCH ]),
    m('sr203', 1, 1, false, false, [ ROLE_STORAGE ]),
    m('embryonic', 3, 1, true, false, [ ROLE_RESEARCH, ROLE_VAT ]),
    m('gestation', 2, 2, false, false, [ ROLE_VAT, ROLE_RESEARCH ]),
    m('drawercab', 2, 1, true, false, [ ROLE_STORAGE, ROLE_WORKSHOP ]),
    m('canisters', 2, 1, true, false, [ ROLE_WORKSHOP, ROLE_STORAGE ]),
    m('controlbox', 1, 1, true, true, [ ROLE_WORKSHOP ]),
    m('rack8', 2, 1, true, false, [ ROLE_STORAGE, ROLE_RESEARCH ]),
    m('rack6', 2, 1, true, false, [ ROLE_STORAGE, ROLE_RESEARCH ]),
    m('drawers', 1, 1, true, true, [ ROLE_STORAGE, ROLE_WORKSHOP ]),
    m('radlocker', 1, 1, true, true, [ ROLE_STORAGE ]),
    // the workshop's floor plant
    m('generator', 2, 1, true, false, [ ROLE_WORKSHOP ]),
    m('press', 1, 1, false, false, [ ROLE_WORKSHOP ]),
    m('robotarm', 1, 1, false, false, [ ROLE_WORKSHOP ]),
    // the lobby's: what was wheeled down and left, and the info terminal by the lift
    m('cagecase', 2, 1, false, false, [ ROLE_ENTRANCE ]),
    m('sheetcage', 2, 1, false, false, [ ROLE_ENTRANCE ]),
    m('gurney', 2, 1, false, false, [ ROLE_ENTRANCE ]),
    m('tarpcrate', 2, 1, false, false, [ ROLE_ENTRANCE, ROLE_STORAGE ]),
    m('incbin', 1, 1, false, false, []),
    m('gurneys', 2, 1, false, false, [ ROLE_ENTRANCE ]),
    m('palletcrate', 2, 1, false, false, [ ROLE_ENTRANCE, ROLE_STORAGE ]),
    m('scanframe', 2, 1, false, false, [ ROLE_ENTRANCE ]),
    m('kiosk', 1, 1, true, true, [ ROLE_ENTRANCE ]),
    // the store's sealed containers
    m('container', 3, 2, true, false, [ ROLE_STORAGE ]),
  ];

// the kind table's index of this name, or -1
  public static function indexOf(name: String): Int
    {
      for (i in 0...MACHINES.length)
        if (MACHINES[i].name == name)
          return i;
      return -1;
    }

// the origin tile of the kind with this name
  public static inline function origin(name: String): Int
    {
      return Const.TILE_LAB_MACHINE0 + indexOf(name);
    }

// the kind a tile names, or null when it is no machine origin
  public static function kindAt(t: Int): _LabMachine
    {
      var i = t - Const.TILE_LAB_MACHINE0;
      return (i >= 0 && i < MACHINES.length ? MACHINES[i] : null);
    }

// does the machine whose origin is (x, y) lie with its long side along x? NOT SAVED, read off the
// footprint: the cell `depth` along from the origin is inside an along-x rect and is exactly the
// ring cell beside an along-y one, and a ring holds no machine (gen.lab.LabRooms.machine), so the
// answer is never another machine's. The cell `len - 1` along was the first probe and it was wrong
// for a 3x1: two cells along it reached PAST the ring into the next machine
  public static function alongX(cells: Array<Array<Int>>, x: Int, y: Int, kind: _LabMachine): Bool
    {
      return kind.len == kind.depth ||
        cells[x + kind.depth][y] == Const.TILE_LAB_MACHINE;
    }

// is this tile part of a machine, its origin or its footprint?
  public static inline function isMachine(t: Int): Bool
    {
      return t == Const.TILE_LAB_MACHINE ||
        kindAt(t) != null;
    }

// one table row
  static function m(name: String, len: Int, depth: Int, wall: Bool, stand: Bool,
      rooms: Array<String>): _LabMachine
    {
      return {
        name: name,
        len: len,
        depth: depth,
        wall: wall,
        stand: stand,
        rooms: rooms,
      };
    }

// the table's own invariants, checked by gen.GenRun before any seed: names unique, every origin id
// inside the tile tables, and its walkability matching `stand`. tiles.Default's two arrays are
// literals, so a kind appended here without its row there is caught before it reaches a game
  public static function selfCheck()
    {
      var walk = tiles.Default.TILE_WALKABLE;
      var seen = new Map<String, Bool>();
      for (i in 0...MACHINES.length)
        {
          var k = MACHINES[i];
          var t = Const.TILE_LAB_MACHINE0 + i;
          if (seen.exists(k.name))
            throw 'LabKinds: duplicate machine ' + k.name;
          seen.set(k.name, true);
          if (t >= walk.length ||
              t >= tiles.Default.TILE_SEETHROUGH.length)
            throw 'LabKinds: ' + k.name + ' origin ' + t + ' is past the tile tables';
          if ((walk[t] == 1) != k.stand)
            throw 'LabKinds: ' + k.name + ' walkable ' + walk[t] + ' but stand ' + k.stand;
          if (k.len < k.depth)
            throw 'LabKinds: ' + k.name + ' is deeper than it is long';
        }
    }
}
