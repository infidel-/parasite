package render.military;

import three.Three;
import render.Area3DTickOpts;
import render.Models;
import render.Models.InstancedProp;
import render.Models.PropPlace;
import render.RenderConfig;
import render.military.MilitaryGeom.ArmoryShell;
import render.world.VisionMask;

// one armory glb's door leaves, in the glb's own frame (+z out of the front, the glTF flip of the
// build script's -y), measured off the built glbs of models-src/military/roomkit_build.py's locker,
// gun_cabinet and safe
typedef DoorLeaves = {
  leafZ:Float,   // a vertex past this depth and within `half` of the centre is a leaf's: under the leaves' back face, which sinks 0.01 into the body front, and over the arrises' inner edge
  gap:Float,     // no leaf comes within this of x = 0 (the bank's divider, the cabinet's seam); -1 for a door across it
  half:Float,    // the leaves' outer edge, |x|, short of the body front's own corners
  hingeZ:Float,  // the leaves' back face, which they turn about
  hingeL:Float,  // the hinge x of the leaf left of the centre, off the art's hinges
  turnL:Float,   // and its turn: -1 hinged on its left edge, 1 on its right
  hingeR:Float,  // the hinge x of the leaf right of it
  turnR:Float,   // and its turn
  frontZ:Float,  // the body front behind the leaves, which an open piece shows dark
  y0:Float,      // the leaves' bottom
  y1:Float,      // and their top
};

// the military armory's lockers, gun cabinet and safe OPENING: render.corp.CorpSecurity's swing and
// ghost door, for glbs MilitaryInterior instances in plain batches with every other piece of
// furniture and that are therefore one material whether open or shut.
//
// THE OPEN ONES ARE A UNIFORM TABLE, not a second glb: every material this patch takes reads
// `uOpen`, each open placement's world xz and how far its leaves have swung, and a vertex finds its
// own placement by its instance matrix's translation — which render.Models.cull repacks freely, so a
// per-instance attribute would lose its place. A shut piece is simply not in the table.
//
// AN OPEN PIECE SHOWS A CAVITY: the glbs are solid boxes with the leaves stood proud, so the body
// front a leaf swings off is darkened to the inside of a steel box. And the player standing at an open
// one sees through its leaves alone, which swing through the cell: the solid drops them there and the
// GHOST twin (`variants`) draws only them, faded as render.world.ObjModels.cull fades a prop
class MilitaryDoors
{
  // how far an opened leaf turns, radians: the corp gun cabinet's 100 degrees (CorpStyle.GUN_CAB_SWING)
  static inline var SWING = 1.745;
  // and how long it takes, in turns (RenderConfig.BASE_MS), the corp cabinet's too
  static inline var SWING_TURNS = 3.0;
  // what an open piece's body front keeps of its colour behind the leaves
  static inline var CAVITY = 0.15;
  // the open pieces the shader tells apart at once.
  // ponytail: a base with more open pieces than this draws the rest shut; it is one loop bound
  static inline var OPEN_MAX = 24;
  // a placement's translation is a uOpen/uGhost entry's within this
  static inline var AT = 0.01;

  // each open piece's world xz and how far its leaves have swung 0..1, the rest parked far off. One
  // table for every material the patch takes; `tick` fills it
  static var uOpen = { value: [for (_ in 0...OPEN_MAX) new Vector3(1e6, 1e6, 0.0)] };
  // the open piece the player stands at, world xz, or far off for none
  static var uGhost = { value: new Vector2(1e6, 1e6) };
  // the ghost fade, 0 solid .. 1 faded, and the placement it is on
  static var ghostT = 0.0;
  static var ghostShell:ArmoryShell = null;
  static var ghostIdx = -1;

// the leaves of this armory glb, or null for any other
  public static function leaves(path:String):DoorLeaves
    {
      var md = RenderConfig.MODELS;
      // two narrow lockers, each leaf hinged on its own left edge like the art
      if (path == md.militaryLocker)
        return {
          leafZ: 0.63,
          gap: 0.04,
          half: 1.88,
          hingeZ: 0.64,
          hingeL: -1.88,
          turnL: -1.0,
          hingeR: 0.04,
          turnR: -1.0,
          frontZ: 0.65,
          y0: 0.25,
          y1: 3.9,
        };
      // a double door on its outer hinges
      if (path == md.militaryGunCabinet)
        return {
          leafZ: 0.63,
          gap: 0.01,
          half: 1.9,
          hingeZ: 0.64,
          hingeL: -1.9,
          turnL: -1.0,
          hingeR: 1.9,
          turnR: 1.0,
          frontZ: 0.65,
          y0: 0.25,
          y1: 3.9,
        };
      // one door across the middle, hinged on the left
      if (path == md.militarySafe)
        return {
          leafZ: 0.787,
          gap: -1.0,
          half: 0.82,
          hingeZ: 0.79,
          hingeL: -0.82,
          turnL: -1.0,
          hingeR: -0.82,
          turnR: -1.0,
          frontZ: 0.8,
          y0: 0.16,
          y1: 1.847,
        };
      return null;
    }

// the armory glbs and their heights, for View's warm: FacilityWarm takes the GHOST and the hull here
// and patches the solid in this file's order
  public static function warmRows():Array<{ path:String, h:Float, ?doors:Bool }>
    {
      return [for (p in MilitaryInterior.warmProps())
        if (leaves(p.path) != null)
          {
            path: p.path,
            h: p.h,
            doors: true,
          }];
    }

// swing the leaves of every armory glb's shared SOLID material. AFTER the vision mask, which is the
// order FacilityWarm patches it in, or the chain's key is one the warm never compiled
  public static function patchSolids():Void
    {
      for (p in warmRows())
        patchSolid(p.path);
    }

// and of one of them
  public static function patchSolid(path:String):Void
    {
      var l = leaves(path);
      Models.get(path, function(t)
        {
          // Dynamic: the template mesh, whose material the extern's Object3D does not carry
          var mesh:Dynamic = Models.firstMesh(t.pivot.children[0]);
          patch(mesh.material, l, 's');
        });
    }

// an armory glb's GHOST twin and outline hull over these placements, both patched: the ghost in the
// vision mask too, as the solid is, or the leaves brighten as they hand over
  public static function variants(scene:Scene, path:String, places:Array<PropPlace>,
      h:Float):{ ghost:InstancedProp, hull:InstancedProp }
    {
      var C = RenderConfig.OBJMARK;
      var ghost = Models.instanced(scene, path, places, h, GHOST);
      var hull = Models.instanced(scene, path, places, h, HULL(C.color, C.hullW));
      var l = leaves(path);
      Models.get(path, function(_)
        {
          patch(ghost.mesh.material, l, 'g');
          VisionMask.patchMesh(ghost.mesh);
          patch(hull.mesh.material, l, 'h');
        });
      return {
        ghost: ghost,
        hull: hull,
      };
    }

// a new base's armory: nothing is fading yet
  public static function reset():Void
    {
      ghostT = 0.0;
      ghostShell = null;
      ghostIdx = -1;
      uGhost.value.set(1e6, 1e6);
    }

// advance the leaves of every open piece and list them for the shader, then fade the leaves of the
// open one the player stands at, render.world.ObjModels.cull's ease. Once per frame, from
// MilitaryGeom.cullShells, which culls the ghost batches with the masks set here
  public static function tick(shells:Array<ArmoryShell>, opts:Area3DTickOpts):Void
    {
      var G = RenderConfig.PROP_GHOST;
      var step = opts.dtMs * RenderConfig.ANIM_SPEED / (RenderConfig.BASE_MS * SWING_TURNS);
      // the leave-outro reports cell 0/0, a legal cell: nobody stands anywhere
      var col = opts.outro ? -1 : opts.playerCol;
      var row = opts.outro ? -1 : opts.playerRow;
      var n = 0;
      var at:ArmoryShell = null;
      var atIdx = -1;
      for (s in shells)
        {
          // the placements' centres land with the glb
          if (s.hull.mesh == null)
            continue;
          for (i in 0...s.objects.length)
            {
              var o = s.objects[i];
              if (!o.isOpen)
                continue;
              s.swing[i] = Math.min(1.0, s.swing[i] + step);
              if (n < OPEN_MAX)
                {
                  uOpen.value[n].set(s.hull.centres[i].x, s.hull.centres[i].z, s.swing[i]);
                  n++;
                }
              if (o.x == col &&
                  o.y == row)
                {
                  at = s;
                  atIdx = i;
                }
            }
        }
      for (k in n...OPEN_MAX)
        uOpen.value[k].set(1e6, 1e6, 0.0);
      // the fading placement stays the ghost's for the whole fade, both ways
      if (at != null)
        {
          ghostShell = at;
          ghostIdx = atIdx;
        }
      var k = 1 - Math.pow(1 - G.lerp, opts.dtMs / (1000 / 30));
      ghostT += ((at != null ? 1.0 : 0.0) - ghostT) * k;
      if (at == null &&
          ghostT < G.snap)
        ghostT = 0.0;
      var on = (ghostShell != null &&
        (at != null || ghostT > 0));
      if (on)
        uGhost.value.set(ghostShell.hull.centres[ghostIdx].x, ghostShell.hull.centres[ghostIdx].z);
      else uGhost.value.set(1e6, 1e6);
      for (s in shells)
        {
          for (i in 0...s.ghostMask.length)
            s.ghostMask[i] = (on &&
              s == ghostShell &&
              i == ghostIdx);
          if (s.ghost.mesh != null)
            s.ghost.mesh.material.opacity = 1 - ghostT * (1 - G.alpha);
        }
    }

// turn the leaves of the placements uOpen lists about their hinges in the vertex shader, eased so a
// door leaves and lands softly. `mode` is the batch: 's' the solid, which also darkens the body front
// an open piece's leaves uncover and drops the leaves of the one at uGhost; 'g' its ghost, which draws
// those leaves alone; 'h' the outline hull, whose normal offset comes back off before the leaf test,
// or the shell round the body front would read as leaf (CorpSecurity.swing's reason). The hull's
// offset is OBJMARK.hullW over the instance scale, which is 1: the glbs are authored at the heights
// MilitaryInterior draws them at
// Dynamic: three's onBeforeCompile hook is not in the extern, every shader patch here takes it so
  static function patch(mat:Dynamic, l:DoorLeaves, mode:String):Void
    {
      if (mat.onBeforeCompile != null &&
          mat.onBeforeCompile.milDoor == true)
        return;
      var inflate = (mode == 'h' ? RenderConfig.OBJMARK.hullW : 0.0);
      // per material, so the three glbs share one program
      var leaf = { value: new Vector4(l.leafZ, l.gap, l.half, l.hingeZ) };
      var hinge = { value: new Vector4(l.hingeL, l.turnL, l.hingeR, l.turnR) };
      var cav = { value: new Vector3(l.frontZ, l.y0, l.y1) };
      var prev:Dynamic = mat.onBeforeCompile;
      // an OWN key only, IndoorMask.patch's reason
      var prevKey:Dynamic = untyped mat.hasOwnProperty('customProgramCacheKey') ?
        mat.customProgramCacheKey : null;
      var hook:Dynamic = function(shader:Dynamic, renderer:Dynamic)
        {
          if (prev != null)
            prev(shader, renderer);
          shader.uniforms.milOpen = uOpen;
          shader.uniforms.milGhost = uGhost;
          shader.uniforms.milLeaf = leaf;
          shader.uniforms.milHinge = hinge;
          shader.uniforms.milCav = cav;
          var p = 'position - normal * float(' + inflate + ')';
          shader.vertexShader =
            'uniform vec3 milOpen[' + OPEN_MAX + '];\n' +
            'uniform vec2 milGhost;\n' +
            'uniform vec4 milLeaf;\n' +
            'uniform vec4 milHinge;\n' +
            'varying float vMilLeaf;\n' +
            'varying float vMilAt;\n' +
            'varying float vMilOpen;\n' +
            'varying vec3 vMilPos;\n' +
            'float milSwing()\n' +
            '{\n' +
            '  for (int i = 0; i < ' + OPEN_MAX + '; i++)\n' +
            '    if (distance(instanceMatrix[3].xz, milOpen[i].xy) < float(' + AT + '))\n' +
            '      return milOpen[i].z;\n' +
            '  return 0.0;\n' +
            '}\n' +
            'bool milIsLeaf(vec3 p)\n' +
            '{\n' +
            '  return p.z > milLeaf.x && abs(p.x) < milLeaf.z + 0.01;\n' +
            '}\n' +
            'mat3 milTurn(vec3 p)\n' +
            '{\n' +
            '  float a = smoothstep(0.0, 1.0, milSwing()) * float(' + SWING + ') *\n' +
            '    (p.x < 0.0 ? milHinge.y : milHinge.w);\n' +
            '  float c = cos(a);\n' +
            '  float s = sin(a);\n' +
            '  return mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c);\n' +
            '}\n' + shader.vertexShader;
          // the normal BEFORE defaultnormal_vertex turns it into view space; a hull has none to turn
          shader.vertexShader = StringTools.replace(shader.vertexShader,
            '#include <beginnormal_vertex>',
            '#include <beginnormal_vertex>\n' +
            '  if (milIsLeaf(' + p + '))\n' +
            '    objectNormal = milTurn(' + p + ') * objectNormal;');
          // the hinge side off the as-built x: a hull vertex on the seam is pushed across it
          shader.vertexShader = StringTools.replace(shader.vertexShader,
            '#include <begin_vertex>',
            '#include <begin_vertex>\n' +
            '  vec3 milP = ' + p + ';\n' +
            '  vMilLeaf = milIsLeaf(milP) ? 1.0 : 0.0;\n' +
            '  vMilAt = distance(instanceMatrix[3].xz, milGhost) < float(' + AT + ') ? 1.0 : 0.0;\n' +
            '  vMilOpen = milSwing();\n' +
            '  vMilPos = milP;\n' +
            '  if (vMilLeaf > 0.5)\n' +
            '    {\n' +
            '      vec3 milH = vec3(milP.x < 0.0 ? milHinge.x : milHinge.z, 0.0, milLeaf.w);\n' +
            '      transformed = milH + milTurn(milP) * (transformed - milH);\n' +
            '    }');
          if (mode == 'h')
            return;
          shader.fragmentShader =
            'uniform vec4 milLeaf;\n' +
            'uniform vec3 milCav;\n' +
            'varying float vMilLeaf;\n' +
            'varying float vMilAt;\n' +
            'varying float vMilOpen;\n' +
            'varying vec3 vMilPos;\n' +
            StringTools.replace(shader.fragmentShader, '#include <clipping_planes_fragment>',
              '#include <clipping_planes_fragment>\n' +
              (mode == 'g' ?
                '  if (vMilLeaf < 0.5)\n' +
                '    discard;' :
                '  if (vMilLeaf > 0.5 && vMilAt > 0.5)\n' +
                '    discard;'));
          if (mode == 'g')
            return;
          // the body front inside the leaves' outline, the divider and the seam left standing
          shader.fragmentShader = StringTools.replace(shader.fragmentShader,
            '#include <map_fragment>',
            '#include <map_fragment>\n' +
            '  if (vMilOpen > 0.0 &&\n' +
            '      vMilLeaf < 0.5 &&\n' +
            '      abs(vMilPos.z - milCav.x) < 0.004 &&\n' +
            '      abs(vMilPos.x) > milLeaf.y &&\n' +
            '      abs(vMilPos.x) < milLeaf.z &&\n' +
            '      vMilPos.y > milCav.y &&\n' +
            '      vMilPos.y < milCav.z)\n' +
            '    diffuseColor.rgb *= mix(1.0, float(' + CAVITY + '), smoothstep(0.0, 0.3, vMilOpen));');
        };
      if (prev != null)
        for (f in Reflect.fields(prev))
          Reflect.setField(hook, f, Reflect.field(prev, f));
      hook.milDoor = true;
      mat.onBeforeCompile = hook;
      mat.customProgramCacheKey = function()
        return (prevKey != null ? Std.string(Reflect.callMethod(mat, prevKey, [])) : '') +
          'mildoor' + mode;
      mat.needsUpdate = true;
    }
}
