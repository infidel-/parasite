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
          },
        }
      ];
    }
}
