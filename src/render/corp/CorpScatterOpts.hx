package render.corp;

import render.facility.ClutterSlot;
import render.world.MeshBuf.MeshBuf;

// one PACK16 scatter over a flat rect, for render.corp.CorpClutter.scatter. Replaced its nine
// positional args, which the kitchen's item size would have made ten
typedef CorpScatterOpts = {
  // the sheet's merged buffer the decals go into
  b:MeshBuf,
  // the rect's centre, world
  x:Float,
  z:Float,
  // its half extents along world x and z, already pulled in by any inset
  hw:Float,
  hd:Float,
  // the height the decals lie at
  y:Float,
  // how many items to try for
  want:Int,
  // the rect's hash, which every roll is taken off
  seed:Int,
  // the boxes already standing on the rect, which the scatter keeps clear of and adds to
  spots:Array<ClutterSlot>,
  // an item's smallest edge, and how much bigger the roll may make it
  sz:Float,
  szVar:Float,
}
