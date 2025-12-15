// data for generic lawfare profane ordeals
package cult.ordeals.profane;

class LawfareConst extends OrdealConst
{
  public function new()
    {
      super();
      infos = [
        { 
          name: 'Evidence Room Epiphany', 
          note: 'Scar photographs on her light table. Chronological order spells her own surname. Indictment motion due in three hours.',
          success: 'She files dismissal. Calls scars <q>persecution</q>. Case suffocates in chambers.',
          fail: 'Press conference live. Scar maps displayed. <q>Self mutilation cult</q> trends. Warrant issued.',
          mission: MISSION_PERSUADE,
          target: {
            isMale: false,
            job: 'prosecutor',
            icon: 'formalCivilian',
            type: 'civilian',
            location: AREA_CITY_HIGH,
          },
        },
        { 
          name: 'Tissue Sample Gospel', 
          note: 'Vial of marrow on his bench. DNA spirals into your sigil. Peer review in six hours. His tenure review next month.',
          success: 'He logs <q>contamination</q>. Vial evaporates. Inquiry terminates. Flock remains ghosts in data.',
          fail: 'Paper publishes. <q>Novel genetic markers</q> trends. Academic interest blooms. You are specimen.',
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: 'forensic scientist',
            icon: 'scientist',
            type: 'scientist',
            location: AREA_FACILITY,
          },
        },
        { 
          name: 'Memorandum of Flesh', 
          note: 'Judge drafting opinion. Clerk catalogued flesh codex among exhibits. Religious freedom precedent hangs in balance. Two hours.',
          success: 'Ruling: scars constitute <q>deeply held belief</q>. Shield of law raised. Flock multiplies.',
          fail: 'Opinion: <q>Clear public harm</q> outweighs. Scar rituals criminalized. You are outlawed.',
          mission: MISSION_PERSUADE,
          target: {
            job: 'law clerk',
            icon: 'formalCivilian',
            type: 'civilian',
            location: AREA_CITY_HIGH,
          },
        },
        {
          name: "Subpoena in crimson ink",
          note: "Corporate archiver catalogs our digital footprints between whiskey sips. His flesh becomes the parchment for our next legal maneuver. Silence him before deposition.",
          success: "Alley stench of iron and ozone. His credentials dissolve. Resignation typed on flayed skin.",
          fail: "He vanishes into witness protection. Our attorneys find his signature on every restraining order. The hunt begins.",
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: "corporate counsel",
            type: "corpo",
            icon: "corpo",
            location: AREA_CORP,
          }
        },
        {
          name: "Blue wall of silence breaks",
          note: "Detective cultivates informants among the faithful. Her ledger connects six disappearances to our abattoir. She patrols the night market district. End her investigation.",
          success: "Alley narrows between precinct and pizzeria. Her badge melts in our crucible. Roll call smells of cooked pork and fear.",
          fail: "She delivers her findings to IA. Internal affairs raids the safehouse. Our lawyers cannot suppress the body cam footage.",
          mission: MISSION_KILL,
          target: {
            isMale: false,
            job: "detective",
            type: "police",
            icon: "police",
            location: AREA_CITY_MEDIUM,
          }
        },
        {
          name: "Testimony of marbled flesh",
          note: "Street solicitor services three councilmen in our pocket. She witnessed the archivist's work in the meat cellar. Her tongue flaps like a plaintiff's flag. Remove the witness.",
          success: "Alley behind the motel. Her final client list bleeds into our ledger. The precinct buries another Jane Doe.",
          fail: "She testifies before grand jury. Her description of our rites is too vivid. The political capital hemorrhages.",
          mission: MISSION_KILL,
          target: {
            isMale: false,
            job: "escort",
            type: "prostitute",
            icon: "prostitute",
            location: AREA_CITY_LOW,
          }
        }
      ];
    }
}
