package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityModel.Wall;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the fadeable halves of one structure's shell. two lists rather than one, because they fade to
// DIFFERENT levels: the roof goes all the way and the walls stop at FacilityStyle.WALL_FADE so the
// floor plan keeps its edges. render.facility.FacilityArea drives both off one eased number
typedef Shell = {
  roof:Array<Mesh>,
  wall:Array<Mesh>,
};

// the static shell of every facility structure: indoor floors, walls, window openings and the roof,
// built from the saved cell grid. one merged mesh per (structure, surface) — a structure is the unit
// because the roof fade is per building, so a mesh may never span two of them.
//
// nothing here is a citygen Building, so render.Occlusion never runs on a facility: the shell fades
// on the player being INSIDE it rather than on blocking a sightline, which is a different question
// with a different answer (see FacilityArea.reveal)
class FacilityGeom
{
  static inline var CELL = CityConfig.CELL;

  // cell offsets of the neighbour each wall face looks at. 0 = north (-z), 1 = south (+z),
  // 2 = west (-x), 3 = east (+x) — the same order render.sewer.SewerGeom winds
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// build every structure's shell, and hand back what fades
  public static function build(scene:Scene, m:Facility):Array<Shell>
    {
      // the vertical band a window opening occupies on its own run's cells, so the wall emitter can
      // leave a hole rather than paint over the pane. keyed per cell because a face is emitted per
      // cell while a pane is emitted per RUN
      var sill = [for (_ in 0...m.h) [for (_ in 0...m.w) -1.0]];
      var head = [for (_ in 0...m.h) [for (_ in 0...m.w) -1.0]];
      for (w in m.windows)
        {
          var wide = w.len * CELL;
          var tall = wide / FacilityStyle.WINDOW_ASPECT;
          var lo = (FacilityStyle.WALL_H - tall) / 2;
          if (lo < 0)
            lo = 0;
          var hi = lo + tall;
          if (hi > FacilityStyle.WALL_H)
            hi = FacilityStyle.WALL_H;
          for (i in 0...w.len)
            {
              var c = w.col + (w.alongX ? i : 0);
              var r = w.row + (w.alongX ? 0 : i);
              sill[r][c] = lo;
              head[r][c] = hi;
            }
        }

      var out = [];
      for (si in 0...m.structures.length)
        out.push(structure(scene, m, si, sill, head));
      return out;
    }

// one structure: its floors, its walls, its window panes and its roof
  static function structure(scene:Scene, m:Facility, si:Int,
      sill:Array<Array<Float>>, head:Array<Array<Float>>):Shell
    {
      var st = m.structures[si];
      var half = (CityConfig.GRID * CELL) / 2;
      // floors, one buffer per surface. a hangar rolls no lab tile and a lab building no concrete,
      // so most of these come back empty and emit no mesh at all
      var fTile = MeshBufTools.make();
      var fLino = MeshBufTools.make();
      var fGrate = MeshBufTools.make();
      var fConcrete = MeshBufTools.make();
      // walls, split by whether the face points SOUTH: that is the only direction that can stand
      // between this camera and the player, so it is the only one that has to fade
      var wOut = MeshBufTools.make();
      var wOutS = MeshBufTools.make();
      var wIn = MeshBufTools.make();
      var wInS = MeshBufTools.make();
      // the roof, split by whether it is over floor (fades) or over the wall ring (never does). the
      // rim is what keeps the building's outline on screen once you are inside it
      var roof = MeshBufTools.make();
      var rim = MeshBufTools.make();
      // window panes, split the same way as the walls
      var panes = MeshBufTools.make();
      var panesS = MeshBufTools.make();

      for (row in st.oy1...st.oy2 + 1)
        for (col in st.ox1...st.ox2 + 1)
          {
            if (!FacilityModel.inside(m, col, row) ||
                m.owner[row][col] != si)
              continue;
            var x0 = col * CELL - half, x1 = x0 + CELL;
            var z0 = row * CELL - half, z1 = z0 + CELL;
            if (FacilityModel.isWall(m, col, row))
              {
                cap(rim, x0, x1, z0, z1, FacilityStyle.ROOF_Y, FacilityStyle.ROOF_TILE);
                for (dir in 0...4)
                  {
                    var nc = col + DC[dir];
                    var nr = row + DR[dir];
                    if (FacilityModel.isWall(m, nc, nr))
                      continue;
                    // a face looking at indoor floor is an inside face; anything else — the lot, the
                    // grass, the walkway, or off the grid entirely — is the outside of the building
                    var inner = FacilityModel.isIndoor(m, nc, nr);
                    var south = (dir == 1);
                    var b = st.hangar || !inner ?
                      (south ? wOutS : wOut) :
                      (south ? wInS : wIn);
                    if (sill[row][col] < 0)
                      {
                        face(b, x0, x1, z0, z1, dir, 0.0, FacilityStyle.WALL_H);
                        continue;
                      }
                    // a window run: leave the opening and carry the wall above and below it
                    face(b, x0, x1, z0, z1, dir, 0.0, sill[row][col]);
                    face(b, x0, x1, z0, z1, dir, head[row][col], FacilityStyle.WALL_H);
                  }
                continue;
              }
            cap(roof, x0, x1, z0, z1, FacilityStyle.ROOF_Y, FacilityStyle.ROOF_TILE);
            var b = switch (m.surf[row][col])
              {
                case Surf.LINO: fLino;
                case Surf.GRATE: fGrate;
                case Surf.CONCRETE: fConcrete;
                default: fTile;
              };
            var t = m.surf[row][col] == Surf.GRATE ?
              FacilityStyle.GRATE_TILE : FacilityStyle.FLOOR_TILE_SZ;
            cap(b, x0, x1, z0, z1, 0.0, t);
          }

      // one pane per RUN and not per cell, so the art's three panes span the whole opening exactly
      // once. both faces get one: a window read only from outside would vanish the moment the roof
      // faded and the player was standing next to it
      for (w in m.windows)
        {
          if (w.structure != si)
            continue;
          var wide = w.len * CELL;
          var tall = wide / FacilityStyle.WINDOW_ASPECT;
          var lo = (FacilityStyle.WALL_H - tall) / 2;
          if (lo < 0)
            lo = 0;
          var x0 = w.col * CELL - half;
          var z0 = w.row * CELL - half;
          var x1 = x0 + (w.alongX ? wide : CELL);
          var z1 = z0 + (w.alongX ? CELL : wide);
          // the exterior face is the one AWAY from the interior, and the interior face its opposite
          var outDir = w.alongX ? (w.inDir > 0 ? 0 : 1) : (w.inDir > 0 ? 2 : 3);
          var inFace = w.alongX ? (w.inDir > 0 ? 1 : 0) : (w.inDir > 0 ? 3 : 2);
          pane(outDir == 1 ? panesS : panes, x0, x1, z0, z1, outDir, lo, lo + tall,
            FacilityStyle.WINDOW_EPS);
          pane(inFace == 1 ? panesS : panes, x0, x1, z0, z1, inFace, lo, lo + tall,
            FacilityStyle.WINDOW_EPS);
        }

      var wallTex = st.hangar ? FacilityStyle.WALL_HANGAR : FacilityStyle.WALL_EXTERIOR;
      var shell:Shell = {
        roof: [],
        wall: [],
      };
      add(scene, fTile, FacilityStyle.FLOOR_TILE, true, false, null);
      add(scene, fLino, FacilityStyle.FLOOR_LINO, true, false, null);
      add(scene, fGrate, FacilityStyle.FLOOR_GRATE, true, false, null);
      add(scene, fConcrete, FacilityStyle.FLOOR_CONCRETE, true, false, null);
      add(scene, wOut, wallTex, true, true, null);
      add(scene, wIn, FacilityStyle.WALL_INTERIOR, true, false, null);
      add(scene, wOutS, wallTex, true, true, shell.wall);
      add(scene, wInS, FacilityStyle.WALL_INTERIOR, true, false, shell.wall);
      addPane(scene, panes, null);
      addPane(scene, panesS, shell.wall);
      // the roof takes NO vision mask. it is the one surface whose visibility is decided by where the
      // player STANDS rather than by what they can see: masked, a roof over cells the sweep never
      // reached would sink to the fog colour and the building would read as a hole in its own lot
      // from every angle outside it
      addRoof(scene, rim, false, shell);
      addRoof(scene, roof, true, shell);
      return shell;
    }

// one horizontal cell quad at height y, world-aligned UVs (never stretched)
  static function cap(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, t:Float):Void
    {
      MeshBufTools.quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
        [x0 / t, z1 / t, x1 / t, z1 / t, x1 / t, z0 / t, x0 / t, z0 / t]);
    }

// the run endpoints of a cell-edge face, wound so the FRONT face looks at the neighbour in `dir`.
// derived rather than hand-cased: for a run direction d the quad's normal is (-dz, 0, dx), so each
// direction fixes which end of the edge is wound first. getting this backwards is invisible until a
// whole axis of faces disappears — the failure render.wild.WildRoad's dashes recorded
  static inline function ends(x0:Float, x1:Float, z0:Float, z1:Float, dir:Int):Array<Float>
    {
      return switch (dir)
        {
          case 0: [x1, z0, x0, z0];
          case 1: [x0, z1, x1, z1];
          case 2: [x0, z0, x0, z1];
          default: [x1, z1, x1, z0];
        };
    }

// one vertical wall face spanning y0..y1, UVs world-aligned along the run and up the wall so
// neighbouring faces of one long wall carry a continuous course
  static function face(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float,
      dir:Int, y0:Float, y1:Float):Void
    {
      if (y1 - y0 < 0.01)
        return;
      var e = ends(x0, x1, z0, z1, dir);
      var t = FacilityStyle.WALL_TILE;
      var us = (dir < 2 ? e[0] : e[1]) / t;
      var ue = (dir < 2 ? e[2] : e[3]) / t;
      MeshBufTools.quad(b, [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [us, y0 / t, ue, y0 / t, ue, y1 / t, us, y1 / t]);
    }

// one window pane over a whole run: the same face winding, but the texture maps 0..1 across it
// rather than tiling, and it stands `eps` off the wall plane so nothing depends on polygonOffset
  static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float,
      dir:Int, y0:Float, y1:Float, eps:Float):Void
    {
      var e = ends(x0, x1, z0, z1, dir);
      var ox = (dir == 2 ? -eps : (dir == 3 ? eps : 0.0));
      var oz = (dir == 0 ? -eps : (dir == 1 ? eps : 0.0));
      MeshBufTools.quad(b,
        [e[0] + ox, y0, e[1] + oz], [e[2] + ox, y0, e[3] + oz],
        [e[2] + ox, y1, e[3] + oz], [e[0] + ox, y1, e[1] + oz],
        [0, 0, 1, 0, 1, 1, 0, 1]);
    }

// merge a buffer into one lit mesh. `fade` non-null means the mesh is driven by the reveal, which
// costs it `transparent` — and transparent is set AFTER VisionMask.patch on purpose: the mask reads
// that flag to choose which branch it compiles, and set first it would pick the decal branch and
// fade a hidden wall OUT instead of sinking it toward the fog (see render.wild.WildRoad)
  static function add(scene:Scene, b:MeshBuf, tex:String, recv:Bool, casts:Bool,
      fade:Array<Mesh>):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: THREE.FrontSide,
      }));
      if (fade != null)
        {
          mat.transparent = true;
          mat.opacity = 1.0;
        }
      var mesh = new Mesh(geom(b), mat);
      mesh.receiveShadow = recv;
      mesh.castShadow = casts;
      scene.add(mesh);
      if (fade != null)
        fade.push(mesh);
    }

// the lit window pane. alphaTest and not transparent for the panes that never fade: an alpha-tested
// opaque material draws in one pass and writes depth, which is what stops the room behind it drawing
// through its own frame. every pane is LIT — a facility is staffed at night, and an unlit pane gives
// the player nothing to walk up to
  static function addPane(scene:Scene, b:MeshBuf, fade:Array<Mesh>):Void
    {
      if (b.idx.length == 0)
        return;
      var tex = Textures.loadCroppedTexture(FacilityStyle.WINDOW_LIT, 0.895, 0.446);
      tex.wrapS = tex.wrapT = THREE.ClampToEdgeWrapping;
      var mat = VisionMask.patch(new MeshLambertMaterial({
        map: tex,
        emissiveMap: tex,
        emissive: new Color(0xffffff),
        emissiveIntensity: FacilityStyle.WINDOW_EMISSIVE,
        alphaTest: 0.5,
        side: THREE.FrontSide,
      }));
      if (fade != null)
        {
          mat.transparent = true;
          mat.opacity = 1.0;
        }
      var mesh = new Mesh(geom(b), mat);
      mesh.receiveShadow = false;
      mesh.castShadow = false;
      scene.add(mesh);
      if (fade != null)
        fade.push(mesh);
    }

// the roof. no vision mask (see the call site) and no shadow casting: the moon box follows the
// player, so a roof casting over its own lot would put the whole building in shadow the moment the
// player walked past it
  static function addRoof(scene:Scene, b:MeshBuf, fades:Bool, shell:Shell):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = new MeshLambertMaterial({
        map: Textures.loadTexture(FacilityStyle.ROOF, 'roof', 1),
        side: THREE.FrontSide,
      });
      if (fades)
        {
          mat.transparent = true;
          mat.opacity = 1.0;
        }
      var mesh = new Mesh(geom(b), mat);
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
      if (fades)
        shell.roof.push(mesh);
    }

// one merged buffer as a BufferGeometry
  static function geom(b:MeshBuf):BufferGeometry
    {
      var g = new BufferGeometry();
      g.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      g.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      g.setIndex(b.idx);
      g.computeVertexNormals();
      return g;
    }
}
