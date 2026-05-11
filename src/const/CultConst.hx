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
  ];

// returns metadata for one cult info ID
  public static function info(id: String): CultInfo
    {
      return infos.get(id);
    }
}
