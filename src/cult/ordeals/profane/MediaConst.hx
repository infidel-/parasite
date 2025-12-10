// data for generic media profane ordeals
package cult.ordeals.profane;

class MediaConst extends OrdealConst
{
  public function new()
    {
      super();
      infos = [
        { 
          name: "Viral Sacrament of Flesh", 
          note: "Seventeen frames of hands folding flesh into origami. Syncs to theta waves. Seed it in mommy groups, mukbang streams. Let them mistake compulsion for communion.",
          success: "Clip metastasizes. Viewers wake with sigils carved behind their eyes. Shares multiply like skin grafts. Servers groan.",
          fail: "Debunked as performance art. Algorithm marks gore. Hosts ban accounts, IPs flagged as snuff farms.",
          mission: MISSION_PERSUADE,
        },
        { 
          name: "Anchor's Burden, Unspoken", 
          note: "Scar photographs in her purse. Testimonies on her phone. Two million viewers tonight. Will she speak, or will truth break her?",
          success: "She weeps on air, calls her skin <q>a house of fog.</q> You provide surgeon, narrative. Tomorrow she anchors your psalm.",
          fail: "Expos&#233; airs. Company named, flesh-sigils in HD. Credibility shatters. Initiates scatter like flayed tissue.",
          mission: MISSION_PERSUADE,
          target: { isMale: false }
        },
        { 
          name: "Teaching the Algorithm Prayer", 
          note: "Recommendation engine is a hungry god. Demands flesh, watch-time. Feed it: streaming rituals, scar updates, ASMR suturing. Teach it to evangelize.",
          success: "Beast learns. Your flesh-rites become background radiation - auto-played everywhere. Conversion is cache-effect.",
          fail: "Shadowban. <q>Harmful</q> flags bloom. Whistleblowers leak flesh-nets. Reach throttled. Flock starved.",
          mission: MISSION_PERSUADE,
        }
      ];
    }
}
