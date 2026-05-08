// typed Flesh, Blood, and Bone resource bundle
package cult.base;

class CultBaseResources extends _SaveObject
{
  public var flesh: Int;
  public var blood: Int;
  public var bone: Int;

  public function new(?flesh: Int = 0, ?blood: Int = 0, ?bone: Int = 0)
    {
      init();
      this.flesh = flesh;
      this.blood = blood;
      this.bone = bone;
    }

// init resource fields
  public function init()
    {
      flesh = 0;
      blood = 0;
      bone = 0;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {}

// checks whether this bundle can pay a cost
  public function canAfford(cost: CultBaseResources): Bool
    {
      return (
        flesh >= cost.flesh &&
        blood >= cost.blood &&
        bone >= cost.bone
      );
    }

// spends a cost from this bundle
  public function spend(cost: CultBaseResources)
    {
      flesh -= cost.flesh;
      blood -= cost.blood;
      bone -= cost.bone;
    }

// adds a delta and clamps to cap
  public function add(delta: CultBaseResources, cap: Int)
    {
      flesh = clamp(flesh + delta.flesh, cap);
      blood = clamp(blood + delta.blood, cap);
      bone = clamp(bone + delta.bone, cap);
    }

// checks whether bundle has no resources
  public function isEmpty(): Bool
    {
      return flesh == 0 && blood == 0 && bone == 0;
    }

// creates a copy of this bundle
  public function clone(): CultBaseResources
    {
      return new CultBaseResources(flesh, blood, bone);
    }

// returns compact display text
  public function text(): String
    {
      var parts = [];
      if (flesh > 0)
        parts.push(flesh + ' Flesh');
      if (blood > 0)
        parts.push(blood + ' Blood');
      if (bone > 0)
        parts.push(bone + ' Bone');
      if (parts.length == 0)
        return 'free';
      return parts.join(', ');
    }

// clamps one resource to a stockpile cap
  static function clamp(v: Int, cap: Int): Int
    {
      if (v < 0)
        return 0;
      if (v > cap)
        return cap;
      return v;
    }
}
