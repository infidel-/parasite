package render.lab;

import three.Three;
import citygen.CityConfig;
import render.Area3DTickOpts;
import render.RenderConfig;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.particles.LampPost;

// what the lab's lighting placed, and the two states that drive it live
typedef LabLampSet = {
  rooms:Array<LampPost>,       // the fixtures over each room, in its role's tint
  corridor:Array<LampPost>,    // the strip lights along the corridor
  vat:Array<LampPost>,         // the vat chamber's own fixtures, a sub-list of `rooms`: they die first
  color:Array<Int>,            // every post's own tint and strength, in `all` order, for the alarm
  mul:Array<Float>,            // and the death to ease back from
  phase:Array<Float>,
  all:Array<LampPost>,         // rooms + corridor
  alarm:Float,                 // the strobe's clock, raw ms since the alarm went up; < 0 while quiet
  dead:Float,                  // the lab's death, eased 0 alive to 1 dark
};

// the underground lab's LIGHT SOURCES. Like the compound's ceiling fixtures (render.facility
// .FacilityLamps) a room's fixture draws nothing: the bedrock is the ceiling and the camera never
// sees it, so what reads is the pool each one throws. The 2D lab's room tints are kept — the lobby
// cyan, the clone floor green, the workshop amber, the store red, the research rooms blue — and the
// corridor is cold white.
//
// MOODY BY CONSTRUCTION, not by a dark knob: the lattice is sparse (LAMP_SPACING cells), a spotlight
// pools about one cell round its foot, and between the pools there is only the rig's cold fill. And
// the lab is ABANDONED: about one fixture in LAMP_DEAD_PCT is dead and LAMP_SPUTTER_PCT more sputter,
// by the cell hash, so the same lab breaks the same lamps on every reload (render.sewer.SewerLamps'
// rule, with LampLights' own `phase` doing the sputter).
//
// TWO LIVE STATES, both read off the mission and the vats every frame and neither saved:
//   - THE ALARM (CombatUndergroundLabPurge.leadTriggerDone): every bulb goes LAMP_ALARM red and pulses
//     over BASE_MS * ALARM_MULT. It keeps running after the lab dies — the alarm is on battery
//   - THE LAB DIES once every vat is purged: the vat chamber's fixtures sputter and go out over
//     BASE_MS * DEAD_MULT and the rest drop to DEAD_DIM. A load into a dead lab starts dark
class LabLamps
{
  static inline var CELL = CityConfig.CELL;

// the fixtures over every room and along the corridor
  public static function build(m:Facility):LabLampSet
    {
      var rooms:Array<LampPost> = [], vat:Array<LampPost> = [];
      for (r in m.rooms)
        {
          var surf = LabModel.roleSurf(r.role);
          // the vat chamber takes one fixture a quadrant, none dead: its vats light it, and the
          // lattice's seven pools all went red together under the alarm
          var vats = (surf == Surf.LAB_VAT);
          var nx = (vats ? 2 : Std.int(Math.max(1, Math.round(r.w / LabStyle.LAMP_SPACING))));
          var ny = (vats ? 2 : Std.int(Math.max(1, Math.round(r.h / LabStyle.LAMP_SPACING))));
          var lit = 0, first = null;
          for (i in 0...nx)
            for (j in 0...ny)
              {
                var c = free(m, r, r.x1 + Std.int((i + 0.5) * r.w / nx),
                  r.y1 + Std.int((j + 0.5) * r.h / ny));
                if (first == null)
                  first = c;
                var p = post(c.col, c.row, tint(surf), vats);
                if (p == null)
                  continue;
                lit++;
                rooms.push(p);
                if (surf == Surf.LAB_VAT)
                  vat.push(p);
              }
          // a small room is two or three posts, and the hash killed both of a 10x6 bay's: the dead
          // ones are the room's mood, never the whole of it
          if (lit == 0)
            {
              var p = post(first.col, first.row, tint(surf), true);
              rooms.push(p);
              if (surf == Surf.LAB_VAT)
                vat.push(p);
            }
        }
      // the corridor: row-major greedy, a strip light on the first lino cell far enough from every
      // one already hung — the shape FacilityLamps.corridors takes for the same reason (a corridor is
      // an L or a T as often as a run)
      var corridor:Array<LampPost> = [];
      var placed:Array<{ col:Int, row:Int }> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.LINO ||
                FacilityModel.isDoor(m, col, row))
              continue;
            var far = true;
            for (q in placed)
              if (Math.abs(q.col - col) < LabStyle.LAMP_SPACING &&
                  Math.abs(q.row - row) < LabStyle.LAMP_SPACING)
                far = false;
            if (!far)
              continue;
            placed.push({
              col: col,
              row: row,
            });
            var p = post(col, row, LabStyle.LAMP_CORRIDOR, false);
            if (p != null)
              corridor.push(p);
          }
      var all = rooms.concat(corridor);
      return {
        rooms: rooms,
        corridor: corridor,
        vat: vat,
        color: [for (p in all) p.color],
        mul: [for (p in all) p.mul],
        phase: [for (p in all) p.phase],
        all: all,
        alarm: -1.0,
        dead: 0.0,
      };
    }

// the room cell nearest a lattice point that nothing stands on (LabModel.fromArea marks every
// furniture, shelf-row and machine cell in `deco`), so a pool lights the aisle and not a shelf top;
// the lattice point itself when the room has no free cell
  static function free(m:Facility, r:_Room, col:Int, row:Int):{ col:Int, row:Int }
    {
      for (d in 0...Std.int(Math.max(r.w, r.h)))
        for (dy in -d...d + 1)
          for (dx in -d...d + 1)
            {
              if (Std.int(Math.max(Math.abs(dx), Math.abs(dy))) != d)
                continue;
              var c = col + dx, w = row + dy;
              if (c >= r.x1 &&
                  c <= r.x2 &&
                  w >= r.y1 &&
                  w <= r.y2 &&
                  m.deco[w][c] == 0)
                return {
                  col: c,
                  row: w,
                };
            }
      return {
        col: col,
        row: row,
      };
    }

// one fixture over a cell, or null for a dead one: the cell hash says steady, sputtering or dead;
// `live` keeps a dead roll as a sputtering one (a room's last post)
  static function post(col:Int, row:Int, color:Int, live:Bool):LampPost
    {
      var h = FacilityModel.mix((col * 49979687) ^ (row * 86028121));
      var roll = (h >>> 3) % 100;
      if (roll < LabStyle.LAMP_DEAD_PCT &&
          !live)
        return null;
      // off the cell centre and off its neighbours' strength by the hash, so a lattice of pools does
      // not read as a grid of identical discs
      var c = CityConfig.cellToWorld(col, row);
      var x = c.x + (((h >>> 13) % 21) - 10) * LabStyle.LAMP_JITTER / 10;
      var z = c.z + (((h >>> 18) % 21) - 10) * LabStyle.LAMP_JITTER / 10;
      return {
        x: x,
        z: z,
        y: LabStyle.LAMP_Y,
        tx: x,
        tz: z,
        color: color,
        col: col,
        row: row,
        // phase 0 is the steady marker; a sputtering bulb takes a hashed one
        phase: (roll < LabStyle.LAMP_DEAD_PCT + LabStyle.LAMP_SPUTTER_PCT ?
          0.5 + ((h >>> 11) % 97) / 10 : 0.0),
        flick: 1.0,
        mul: LabStyle.LAMP_MUL * (1 - LabStyle.LAMP_MUL_VAR * ((h >>> 23) % 11) / 10),
        // the room and corridor fixtures throw the lab's furniture shadows (LabInterior.batch casts):
        // the nearest RenderConfig.LAMP_LIGHT.shadowCasters of them, the rest light without
        noCast: false,
      };
    }

// a room role's tint
  static function tint(s:Surf):Int
    {
      return switch (s)
        {
          case Surf.LAB_ENTRANCE: LabStyle.LAMP_ENTRANCE;
          case Surf.LAB_VAT: LabStyle.LAMP_VAT;
          case Surf.LAB_WORKSHOP: LabStyle.LAMP_WORKSHOP;
          case Surf.LAB_STORAGE: LabStyle.LAMP_STORAGE;
          default: LabStyle.LAMP_RESEARCH;
        }
    }

// the alarm and the death, onto every post's published tint and strength. `alarmed` is the mission's
// flag, `dead` whether every vat is purged; the shaft's daylight is neither the lab's alarm nor its
// power, so it is left alone
  public static function tick(set:LabLampSet, opts:Area3DTickOpts, alarmed:Bool, dead:Bool):Void
    {
      if (alarmed &&
          set.alarm < 0)
        set.alarm = 0.0;
      if (set.alarm >= 0)
        set.alarm += opts.dtMs * RenderConfig.ANIM_SPEED;
      var want = (dead ? 1.0 : 0.0);
      if (set.dead != want)
        {
          var step = opts.dtMs * RenderConfig.ANIM_SPEED / (RenderConfig.BASE_MS * LabStyle.DEAD_MULT);
          set.dead = (set.dead < want ? Math.min(want, set.dead + step) : Math.max(want, set.dead - step));
        }
      // the strobe: a slow swell between ALARM_LO and full, the same for every bulb
      var strobe = (set.alarm < 0 ? 1.0 :
        LabStyle.ALARM_LO + (1 - LabStyle.ALARM_LO) *
        (0.5 + 0.5 * Math.sin(set.alarm / (RenderConfig.BASE_MS * LabStyle.ALARM_MULT) * Math.PI * 2)));
      for (i in 0...set.all.length)
        {
          var p = set.all[i];
          var vat = (set.vat.indexOf(p) >= 0);
          // dying: the vat chamber's bulbs all sputter on the way out and end dark; the rest dim
          var life = (vat ? 1 - set.dead : 1 - set.dead * (1 - LabStyle.DEAD_DIM));
          p.phase = (set.dead > 0 && set.dead < 1 ? LabStyle.DEAD_PHASE + i : set.phase[i]);
          p.color = (set.alarm >= 0 ? LabStyle.LAMP_ALARM : set.color[i]);
          p.mul = set.mul[i] * life * strobe;
        }
    }
}
