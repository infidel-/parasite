package render.military;

import three.Three;
import game.AreaGame;
import game.Game;
import render.Models;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.wild.WildBand;
import render.wild.WildHeight;
import render.wild.WildModel;
import render.wild.WildProps;
import render.wild.WildStyle;

// a military base's WILD MARGIN, the ground outside its fence: the terrain band's trees, bushes,
// rocks and thickets, planted by the wilderness's own scatter (render.wild.WildProps) off the same
// tile grid the wilderness reads, so a base in the forest band stands in that forest's wood.
//
// FLAT, where the wilderness rolls: its relief is zeroed for the build, so every prop sits at 0 —
// which is the height render.facility.FacilityGround lays Surf.WILD at. Everything that is not
// margin (the base inside the fence, the road, the verge) is marked covered, which keeps both the
// scatter and its loose stones off it, and the road is not the highway, so no guard rail runs it
class MilitaryMargin
{
// point the wilderness tables at this base's terrain band, flat. called before the facility model's
// ground is built, which reads the band's ground texture
  public static function use(game:Game):Void
    {
      WildBand.use(game);
      WildBand.reliefAmp = 0.0;
      WildHeight.use(game.area.id);
    }

// plant the margin. returns the batches, which the area's tick culls
  public static function build(scene:Scene, area:AreaGame, m:Facility):Array<InstancedProp>
    {
      var w = WildModel.fromArea(area);
      w.road = null;
      for (row in 0...w.h)
        for (col in 0...w.w)
          if (m.surf[row][col] != Surf.WILD)
            w.prop[row][col] = WildModel.OCCUPIED;
      return WildProps.build(scene, w);
    }

// the margin's glbs, for the base's shader warm (render.View.warmKind): every row of the wilderness
// table, whichever band the first base entered is in
  public static function warmProps():Array<{ path:String, h:Float }>
    {
      return [for (p in WildStyle.PROPS) {
        path: p.path,
        h: p.h,
      }];
    }
}
