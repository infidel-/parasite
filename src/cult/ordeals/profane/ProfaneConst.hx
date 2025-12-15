package cult.ordeals.profane;

// profane ordeal constants manager
class ProfaneConst {
  // map of subtype to their const instances
  public static var constMap: Map<String, OrdealConst> = new Map();
  // available profane ordeal types
  public static var availableTypes: Array<String> = ['media', 'lawfare', 'corpo', 'political'];

  // initialize profane ordeal constants
  public static function init()
    {
      for (type in availableTypes)
        {
          if (type == 'media')
            constMap.set(type, new MediaConst());
          else if (type == 'lawfare')
            constMap.set(type, new LawfareConst());
          else if (type == 'corpo')
            constMap.set(type, new CorpoConst());
          else if (type == 'political')
            constMap.set(type, new PoliticalConst());
        }
    }

// get random ordeal index for subtype
  public static function getRandom(subType: String): Int
    {
      var cc = constMap.get(subType);
      if (cc != null)
        return cc.getRandom();
      return 0;
    }

  // get ordeal info for subtype and index
  public static function getInfo(subType: String, index: Int): _OrdealInfo
    {
      var cc = constMap.get(subType);
      if (cc != null)
        return cc.getInfo(index);
      return {
        name: "Unknown Ordeal",
        note: "This ordeal type is not properly configured.",
        success: "The ordeal completed successfully.",
        fail: "The ordeal failed.",
        mission: MISSION_PERSUADE
      };
    }
}
