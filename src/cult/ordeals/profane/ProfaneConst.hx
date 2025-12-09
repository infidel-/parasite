package cult.ordeals.profane;

// profane ordeal constants manager
class ProfaneConst {
  // map of subtype to their const instances
  public static var constMap: Map<String, OrdealConst> = new Map();

  // initialize profane ordeal constants
  public static function init()
    {
      constMap.set('media', new MediaConst());
    }

// get random ordeal index for subtype
  public static function getRandom(subType: String): Int
    {
      var constInstance = constMap.get(subType);
      if (constInstance != null)
        return constInstance.getRandom();
      return 0;
    }

  // get ordeal info for subtype and index
  public static function getInfo(subType: String, index: Int): _OrdealInfo
    {
      var constInstance = constMap.get(subType);
    if (constInstance != null)
      return constInstance.getInfo(index);
      return {
        name: "Unknown Ordeal",
        note: "This ordeal type is not properly configured.",
        success: "The ordeal completed successfully.",
        fail: "The ordeal failed.",
        mission: MISSION_PERSUADE
      };
    }
}
