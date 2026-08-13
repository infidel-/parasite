package render;

import entities.Entity;

// the pose + flags render.Actors.paintObjMark paints a world object's marks at. replaced
// paintObjMark(e, op, x, y, z, scale, flat, yaw, order), which was already at 9 positional args
// when the through-wall silhouette needed a switch of its own
typedef ObjMarkOpts = {
  e:Entity,     // the object's entity — supplies the atlas cell both marks are carved from
  op:Float,     // fade opacity, matching the icon the marks frame
  x:Float,      // world X of the sprite pose
  y:Float,      // world Y of the sprite pose
  z:Float,      // world Z of the sprite pose
  scale:Float,  // billboard scale of the sprite pose
  flat:Bool,    // the pose lies flat as a ground decal instead of standing up
  yaw:Float,    // ground rotation of a flat pose
  order:Int,    // render order shared with the icon
};
