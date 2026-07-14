package render.choreo;

// organ gas-cloud choreography (panic / paralysis): a wide low additive shader dome over the
// emission cell that bursts then lingers + fades. no 2D analog was ever ported — replaces the flat
// per-tile AreaView effect tiles that draw invisibly under the 3D canvas
class Gas {

// choreograph a gas cloud at cell (x,y). returns true if the view took over (caller then skips the
// 2D per-tile effect tiles)
  public static function play(c:Choreo, kind:String, x:Int, y:Int, range:Int):Bool
    {
      c.actors.gasCloud(x, y, kind, range);
      return true;
    }
}
