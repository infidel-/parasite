// data for generic lawfare profane ordeals
package cult.ordeals.profane;

class LawfareConst extends OrdealConst
{
  public function new()
    {
      super();
      infos = [
        { 
          name: N('Evidence Room Epiphany'),
          note: N('Scar photographs on her light table. Chronological order spells her own surname. Indictment motion due in three hours.'),
          success: T('She files dismissal. Calls scars <q>persecution</q>. Case suffocates in chambers.'),
          fail: T('Press conference live. Scar maps displayed. <q>Self mutilation cult</q> trends. Warrant issued.'),
          mission: MISSION_PERSUADE,
          target: {
            isMale: false,
            job: N('prosecutor'),
            icon: 'formalCivilian',
            type: 'civilian',
            location: AREA_CITY_HIGH,
          },
        },
        { 
          name: N('Tissue Sample Gospel'),
          note: N('Vial of marrow on his bench. DNA spirals into your sigil. Peer review in six hours. His tenure review next month.'),
          success: T('He logs <q>contamination</q>. Vial evaporates. Inquiry terminates. Flock remains ghosts in data.'),
          fail: T('Paper publishes. <q>Novel genetic markers</q> trends. Academic interest blooms. You are specimen.'),
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: N('forensic scientist'),
            icon: 'scientist',
            type: 'scientist',
            location: AREA_FACILITY,
          },
        },
        { 
          name: N('Memorandum of Flesh'),
          note: N('Judge drafting opinion. Clerk catalogued flesh codex among exhibits. Religious freedom precedent hangs in balance. Two hours.'),
          success: T('Ruling: scars constitute <q>deeply held belief</q>. Shield of law raised. Flock multiplies.'),
          fail: T('Opinion: <q>Clear public harm</q> outweighs. Scar rituals criminalized. You are outlawed.'),
          mission: MISSION_PERSUADE,
          target: {
            job: N('law clerk'),
            icon: 'formalCivilian',
            type: 'civilian',
            location: AREA_CITY_HIGH,
          },
        },
        {
          name: N("Subpoena in crimson ink"),
          note: N("Corporate archiver catalogs our digital footprints between whiskey sips. His flesh becomes the parchment for our next legal maneuver. Silence him before deposition."),
          success: T("Alley stench of iron and ozone. His credentials dissolve. Resignation typed on flayed skin."),
          fail: T("He vanishes into witness protection. Our attorneys find his signature on every restraining order. The hunt begins."),
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: N("corporate counsel"),
            type: "corpo",
            icon: "corpo",
            location: AREA_CORP,
          }
        },
        {
          name: N("Blue wall of silence breaks"),
          note: N("Detective cultivates informants among the faithful. Her ledger connects six disappearances to our abattoir. She patrols the night market district. End her investigation."),
          success: T("Alley narrows between precinct and pizzeria. Her badge melts in our crucible. Roll call smells of cooked pork and fear."),
          fail: T("She delivers her findings to IA. Internal affairs raids the safehouse. Our lawyers cannot suppress the body cam footage."),
          mission: MISSION_KILL,
          target: {
            isMale: false,
            job: N("detective"),
            type: "police",
            icon: "police",
            location: AREA_CITY_MEDIUM,
          }
        },
        {
          name: N("Testimony of marbled flesh"),
          note: N("Street solicitor services three councilmen in our pocket. She witnessed the archivist's work in the meat cellar. Her tongue flaps like a plaintiff's flag. Remove the witness."),
          success: T("Alley behind the motel. Her final client list bleeds into our ledger. The precinct buries another Jane Doe."),
          fail: T("She testifies before grand jury. Her description of our rites is too vivid. The political capital hemorrhages."),
          mission: MISSION_KILL,
          target: {
            isMale: false,
            job: N("escort"),
            type: "prostitute",
            icon: "prostitute",
            location: AREA_CITY_LOW,
          }
        }
      ];
    }
}
