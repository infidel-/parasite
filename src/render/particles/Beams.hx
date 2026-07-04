package render.particles;

import three.Three;

// a pooled layer of unlit additive flat quads for bright FX (gun tracers, muzzle flash, impact
// sparks). the sibling of Sprites for glowing geometry: Sprites is lit + uniform-scale (for
// billboard actors + decals), Beams is unlit + additive + non-uniform (streaks that bloom).
// pooled so a firefight allocates nothing and each quad's material compiles once, not per shot.
// a frame is begin() -> quad() ... -> end(); each quad reuses the next pooled mesh
class Beams {
  var actorGroup:Group;                                 // scene group holding the quads
  var pool:Array<Mesh> = [];                            // reused quad meshes (own material each)
  var idx:Int = 0;                                      // next free pool slot this frame

  public function new(actorGroup:Group)
    {
      this.actorGroup = actorGroup;
    }

// start a frame: reset to the first pool slot
  public inline function begin():Void
    {
      idx = 0;
    }

// draw a flat horizontal quad centred at (cx,cy,cz), lenX along its local axis and lenZ wide,
// yawed in the ground plane; tinted color at opacity op. additive -> it blooms
  public function quad(cx:Float, cy:Float, cz:Float, lenX:Float, lenZ:Float, yaw:Float, color:Int, op:Float):Void
    {
      var m = pool[idx];
      if (m == null)
        {
          m = new Mesh(new PlaneGeometry(1, 1),
            new MeshBasicMaterial({
              color: color,
              transparent: true,
              opacity: 1.0,
              depthWrite: false,
              side: THREE.DoubleSide,
              blending: untyped THREE.AdditiveBlending,
            }));
          pool[idx] = m;
          actorGroup.add(m);
        }
      var mat:Dynamic = m.material;
      mat.opacity = op;
      untyped mat.color.setHex(color);
      m.position.set(cx, cy, cz);
      m.scale.set(lenX, lenZ, 1);
      // lie flat (normal up), then yaw the length axis to the shot direction
      m.rotation.set(-Math.PI / 2, 0, yaw);
      m.visible = true;
      idx++;
    }

// end a frame: hide every pool quad left untouched this frame
  public function end():Void
    {
      for (i in idx...pool.length)
        if (pool[i] != null) pool[i].visible = false;
    }

// how many quads were drawn this frame (profiler read)
  public inline function count():Int
    return idx;
}
