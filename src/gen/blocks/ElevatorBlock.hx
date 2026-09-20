// the lift core: the car, its doors, its floor and its glazing
//
// A BLOCK AND NOT A ROOM TEMPLATE, because nothing about it is dealt. Everything inside it is fixed
// — a 3x3 car, nine objects.Elevator cells, a concrete floor, four corner posts, glazing on the
// three sides that do not face the building, and one door in the side that does — so there is no
// quota under it and no zones. What varies is only which outer wall it stands against, and that is
// decided by the plate before this node exists.
//
// IT STANDS OUTSIDE THE WALL RING, in the pavement band the plate throws round itself. That is
// where game.CorpAreaGenerator always put it and it is what makes the lift read as a car hanging
// off the tower's face rather than a cupboard inside the floor plate.

package gen.blocks;

import game.AreaGenerator.*;
import gen.GenTree;
import gen.corp._CorpState;
import gen.corp.CorpTemp.*;

class ElevatorBlock
{
  // the car is 3x3 and every one of those cells carries an objects.Elevator
  public static inline var CAR = 3;

// the node covering the car, its ring of posts and glazing, and the door through the tower wall.
//
// the door cell is ON the ring — the car sits three cells out from the wall, so the ring's building
// side IS the wall line — which is why the node is the 5x5 about the car and not the car itself:
// a block's rect has to contain everything the block writes, or GenCheck.inBounds and `go block`
// both describe something smaller than what is there
  public static function node(state: _CorpState, parent: _GenNode,
      doorX: Int, doorY: Int, dir: Int): _GenNode
    {
      var c = car(doorX, doorY, dir);
      return GenTree.add(parent, CorpBlocks.ELEVATOR,
        c.x - 1, c.y - 1, c.x + CAR, c.y + CAR);
    }

// the car's low corner, from the door cell and the direction the corridor runs INWARD from it. the
// car is on the other side of the wall, so it is laid against -dir
  static function car(doorX: Int, doorY: Int, dir: Int): { x: Int, y: Int }
    {
      return switch (dir)
        {
          case DIR_DOWN: { x: doorX - 1, y: doorY - CAR };
          case DIR_UP: { x: doorX - 1, y: doorY + 1 };
          case DIR_RIGHT: { x: doorX - CAR, y: doorY - 1 };
          default: { x: doorX + 1, y: doorY - 1 };
        }
    }

// paint the lift: floor, car cells, posts, glazing, door
  public static function fill(state: _CorpState, node: _GenNode)
    {
      var area = state.area;
      var cells = area.getCells();
      // the node is the 5x5 about the car, so the car is its inset
      var x1 = node.x1 + 1;
      var y1 = node.y1 + 1;
      var x2 = node.x2 - 1;
      var y2 = node.y2 - 1;
      var dir = state.frontDir;

      // the car floor, and the nine invisible objects that make it a working lift. concrete,
      // because a lift car is not carpeted and the id is what render.corp.CorpModel reads it by
      drawBlock(cells, x1, y1, CAR, CAR, CONCRETE);
      for (dy in 0...CAR)
        for (dx in 0...CAR)
          area.add('elevator', x1 + dx, y1 + dy);

      // the four corner posts
      cells[x1 - 1][y1 - 1] = BLDG_WALL;
      cells[x1 - 1][y2 + 1] = BLDG_WALL;
      cells[x2 + 1][y1 - 1] = BLDG_WALL;
      cells[x2 + 1][y2 + 1] = BLDG_WALL;

      // and glazing on every side but the one facing the tower, which carries the door instead.
      // `dir` is the direction the corridor runs inward, so the building is that way from the car
      if (dir != DIR_UP)
        {
          cells[x1][y1 - 1] = BLDG_WINDOWH1;
          cells[x1 + 1][y1 - 1] = BLDG_WINDOWH2;
          cells[x1 + 2][y1 - 1] = BLDG_WINDOWH3;
        }
      if (dir != DIR_DOWN)
        {
          cells[x1][y2 + 1] = BLDG_WINDOWH1;
          cells[x1 + 1][y2 + 1] = BLDG_WINDOWH2;
          cells[x1 + 2][y2 + 1] = BLDG_WINDOWH3;
        }
      if (dir != DIR_LEFT)
        {
          cells[x1 - 1][y1] = BLDG_WINDOWV1;
          cells[x1 - 1][y1 + 1] = BLDG_WINDOWV2;
          cells[x1 - 1][y1 + 2] = BLDG_WINDOWV3;
        }
      if (dir != DIR_RIGHT)
        {
          cells[x2 + 1][y1] = BLDG_WINDOWV1;
          cells[x2 + 1][y1 + 1] = BLDG_WINDOWV2;
          cells[x2 + 1][y1 + 2] = BLDG_WINDOWV3;
        }

      // the car door, in the tower wall the car is bolted to. CorpGen.finalizeTiles turns it into
      // an objects.Door wearing the lift frame
      var delta = deltaMap[dir];
      cells[x1 + 1 + delta.x * 2][y1 + 1 + delta.y * 2] = BLDG_ELEVATOR_DOOR;
    }
}
