// underground lab generation, the Game-free half
//
// build() is the real entry point and the one tools/genrun.mjs calls. It must never reach for a
// game.Game: everything it writes goes into a gen.GenCtx, and the lift and the doors are recorded
// as SPAWN INTENTS that gen.GenSpawner turns into real objects on the live path only.
// game.UndergroundLabAreaGenerator is the thin adapter that does that last step. See
// docs/area-gen.md.
//
// IT WRITES FINAL IDS AND NOTHING ELSE. The compound and the corp floor lay a temp alphabet and
// finalize it, because their passes ask about cells (a corridor, a room mark) the final tiles cannot
// tell apart. Every lab id already says what it is (Const rows 22-28), so there is no temp alphabet
// and no finalize pass.

package gen.lab;

import gen.GenCtx;
import gen.GenTree;
import gen.blocks.LabBlocks;

class LabGen
{
// generate a whole level into a context: bedrock everywhere, then the plate and the walk
  public static function build(ctx: GenCtx): _LabState
    {
      var state: _LabState = {
        area: ctx,
        rooms: [],
        doors: [],
        corridorY: 0,
        cx1: 0,
        cx2: 0,
        vatRoomID: -1,
        vatDoor: null,
        vatAnchors: [],
        reservedRects: [],
        keep: [for (x in 0...ctx.width) [for (y in 0...ctx.height) false]],
        used: [for (k in LabKinds.MACHINES) 0],
        tries: 0,
      };
      var cells = ctx.getCells();
      for (x in 0...ctx.width)
        for (y in 0...ctx.height)
          cells[x][y] = Const.TILE_LAB_ROCK;
      GenTree.add(ctx.root, LabBlocks.PLATE, 1, 1, ctx.width - 2, ctx.height - 2);
      GenTree.build(ctx.root, function(n) fill(state, n));
      return state;
    }

// build one node of the tree. The corridor is a leaf: what dresses it is render-side
  static function fill(state: _LabState, node: _GenNode)
    {
      if (LabBlocks.isRoom(node.kind))
        {
          LabZones.deal(state, node);
          return;
        }
      if (LabZones.isZone(node.kind))
        {
          LabRooms.fill(state, node);
          return;
        }
      switch (node.kind)
        {
          case LabBlocks.PLATE:
            LabPlan.lay(state, node);
          case LabBlocks.LIFT:
            lift(state, node);
          case LabBlocks.DOOR:
            door(state, node);
          default:
        }
    }

// the lift car: its 2x2 and the four objects.Elevator parts on it, and the cells beside it in the
// lobby kept bare, so nothing boxes the way off it in
  static function lift(state: _LabState, node: _GenNode)
    {
      var cells = state.area.getCells();
      for (dy in 0...2)
        for (dx in 0...2)
          {
            var x = node.x1 + dx;
            var y = node.y1 + dy;
            cells[x][y] = Const.TILE_LAB_LIFT;
            state.area.add('labLift', x, y).part = dy * 2 + dx;
          }
      for (x in node.x1 - 1...node.x2 + 2)
        for (y in node.y1 - 1...node.y2 + 2)
          state.keep[x][y] = true;
    }

// a doorway: its two cells, and the linked pair of objects.Door on them, the first cell's first
  static function door(state: _LabState, node: _GenNode)
    {
      var vertical = LabZones.tagged(node, 'v');
      var cells = state.area.getCells();
      var i = 0;
      for (x in node.x1...node.x2 + 1)
        for (y in node.y1...node.y2 + 1)
          {
            cells[x][y] = Const.TILE_LAB_DOOR;
            var s = state.area.add('labDoor', x, y);
            s.part = i++;
            s.vertical = vertical;
          }
    }
}
