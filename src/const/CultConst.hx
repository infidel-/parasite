// cult metadata and helper rules
package const;

typedef CultInfo = {
  var id: String;
  var name: String;
  var note: String;
  var sanctumIcon: _Icon;
  var memberTemplate: String;
  var tactic: _RivalCultTactic;
}

class CultConst
{
  public static inline var RIVAL_CULTUS_FERRI = 'cultusFerri';
  public static inline var RIVAL_CHOIR_BELOW = 'choirBelow';
  public static inline var RIVAL_PHARAONIC_SLUMBER = 'pharaonicSlumber';
  public static inline var RIVAL_BLOODED_MASK = 'bloodedMask';

  public static var infos: Map<String, CultInfo> = [
    RIVAL_CULTUS_FERRI => {
      id: RIVAL_CULTUS_FERRI,
      name: 'Cultus Ferri',
      note: 'A rival cult built around violence, discipline, and iron.',
      sanctumIcon: { row: 4, col: 2 },
      memberTemplate: 'combat',
      tactic: RIVAL_COMBAT,
    },
    RIVAL_CHOIR_BELOW => {
      id: RIVAL_CHOIR_BELOW,
      name: 'The Choir Below',
      note: 'A rival cult built around hidden rites and resonant doctrine.',
      sanctumIcon: { row: 4, col: 4 },
      memberTemplate: 'occult',
      tactic: RIVAL_NON_COMBAT,
    },
    RIVAL_PHARAONIC_SLUMBER => {
      id: RIVAL_PHARAONIC_SLUMBER,
      name: 'Pharaonic Slumber',
      note: 'Abhumans who want the world asleep so they can feed on nightmares. Dimensionally adjacent abhumans once traded power with ancient Egypt in exchange for control over sleeping minds. They now seek permanent global slumber.',
      sanctumIcon: { row: 4, col: 6 },
      memberTemplate: 'occult',
      tactic: RIVAL_NON_COMBAT,
    },
    RIVAL_BLOODED_MASK => {
      id: RIVAL_BLOODED_MASK,
      name: 'Blooded Mask',
      note: 'Cult devoted to tearing away consensus reality and revealing the insane truth beyond it. The Blooded Mask studies the abyss behind ordinary reality. Its revelations cause madness and compel victims to spread the vision.',
      sanctumIcon: { row: 6, col: 0 },
      memberTemplate: 'occult',
      tactic: RIVAL_COMBAT,
    },
  ];

// returns metadata for one cult info ID
  public static function info(id: String): CultInfo
    {
      return infos.get(id);
    }

// returns random rival cult ID with matching tactic
  public static function randomRivalID(tactic: _RivalCultTactic): String
    {
      var ids = [];
      for (id => info in infos)
        if (info.tactic == tactic)
          ids.push(id);
      return ids[Std.random(ids.length)];
    }
}
