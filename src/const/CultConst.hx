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

// one kind of rival roster member: an AI type, and the power group its job is rolled from (null: the type's own job)
typedef RivalMemberKind = {
  var type: String;
  @:optional var group: _AIJobGroup;
}

// how a rival of one tactic is built and how it grows
typedef RivalTuning = {
  // kinds a starting member or a recruit is drawn from (a kind listed twice is drawn twice as often)
  var mix: Array<RivalMemberKind>;
  // members a new rival starts with
  var startMembers: Int;
  // percent chance a starting member is born one job level up, and two levels up
  var level2Pct: Int;
  var level3Pct: Int;
  // percent chance per strategic turn to recruit one level 1 member
  var recruitPct: Int;
  // pressure a strategic turn adds to the player's base
  var pressure: Int;
}

class CultConst
{
  // cult turns between two strategic turns of one rival
  public static inline var RIVAL_TURN_PERIOD = 10;
  // cult turns after a wipe before a rival of the same tactic replaces it: a base value and a random spread
  public static inline var RIVAL_REPLACE_TURNS = 30;
  public static inline var RIVAL_REPLACE_SPREAD = 20;
  // flesh, blood and bone each that wiping out a rival base brings to the player's base
  public static inline var RIVAL_LOOT = 15;
  // percent chance a failed mission against a rival gives it one level 1 member
  public static inline var RIVAL_FAIL_RECRUIT_PCT = 15;

  public static inline var RIVAL_CULTUS_FERRI = 'cultusFerri';
  public static inline var RIVAL_CHOIR_BELOW = 'choirBelow';
  public static inline var RIVAL_PHARAONIC_SLUMBER = 'pharaonicSlumber';
  public static inline var RIVAL_BLOODED_MASK = 'bloodedMask';

  public static var infos: Map<String, CultInfo> = [
    RIVAL_CULTUS_FERRI => {
      id: RIVAL_CULTUS_FERRI,
      name: N('Cultus Ferri'),
      note: 'A rival cult built around violence, discipline, and iron.',
      sanctumIcon: { row: 4, col: 2 },
      memberTemplate: 'combat',
      tactic: RIVAL_COMBAT,
    },
    RIVAL_CHOIR_BELOW => {
      id: RIVAL_CHOIR_BELOW,
      name: N('The Choir Below'),
      note: 'A rival cult built around hidden rites and resonant doctrine.',
      sanctumIcon: { row: 4, col: 4 },
      memberTemplate: 'occult',
      tactic: RIVAL_NON_COMBAT,
    },
    RIVAL_PHARAONIC_SLUMBER => {
      id: RIVAL_PHARAONIC_SLUMBER,
      name: N('Pharaonic Slumber'),
      note: 'Abhumans who want the world asleep so they can feed on nightmares. Dimensionally adjacent abhumans once traded power with ancient Egypt in exchange for control over sleeping minds. They now seek permanent global slumber.',
      sanctumIcon: { row: 4, col: 6 },
      memberTemplate: 'occult',
      tactic: RIVAL_NON_COMBAT,
    },
    RIVAL_BLOODED_MASK => {
      id: RIVAL_BLOODED_MASK,
      name: N('Blooded Mask'),
      note: 'Cult devoted to tearing away consensus reality and revealing the insane truth beyond it. The Blooded Mask studies the abyss behind ordinary reality. Its revelations cause madness and compel victims to spread the vision.',
      sanctumIcon: { row: 6, col: 0 },
      memberTemplate: 'occult',
      tactic: RIVAL_COMBAT,
    },
  ];

  public static var tunings: Map<_RivalCultTactic, RivalTuning> = [
    RIVAL_COMBAT => {
      mix: [
        { type: 'thug' },
        { type: 'thug' },
        { type: 'thug' },
        { type: 'security' },
        { type: 'security' },
        { type: 'soldier' },
      ],
      startMembers: 6,
      level2Pct: 30,
      level3Pct: 5,
      recruitPct: 35,
      pressure: 10,
    },
    RIVAL_NON_COMBAT => {
      mix: [
        { type: 'civilian', group: GROUP_MEDIA },
        { type: 'civilian', group: GROUP_LAWFARE },
        { type: 'civilian', group: GROUP_CORPORATE },
        { type: 'civilian', group: GROUP_POLITICAL },
        { type: 'scientist' },
        { type: 'security' },
      ],
      startMembers: 6,
      level2Pct: 20,
      level3Pct: 0,
      recruitPct: 35,
      pressure: 5,
    },
  ];

// returns metadata for one cult info ID
  public static function info(id: String): CultInfo
    {
      return infos.get(id);
    }

// returns random rival cult ID with matching tactic, one not in the taken list when any is left
  public static function randomRivalID(tactic: _RivalCultTactic, taken: Array<String>): String
    {
      var ids = [];
      for (id => info in infos)
        if (info.tactic == tactic &&
            taken.indexOf(id) < 0)
          ids.push(id);
      if (ids.length == 0)
        for (id => info in infos)
          if (info.tactic == tactic)
            ids.push(id);
      return ids[Std.random(ids.length)];
    }
}
