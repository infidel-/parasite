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
          target: {
            isMale: false,
            job: "content moderator",
            type: "corpo",
            icon: "corpo",
            location: AREA_CORP,
          },
        },
        { 
          name: "Anchor's Burden, Unspoken", 
          note: "Scar photographs in her purse. Testimonies on her phone. Two million viewers tonight. Will she speak, or will truth break her?",
          success: "She weeps on air, calls her skin <q>a house of fog.</q> You provide surgeon, narrative. Tomorrow she anchors your psalm.",
          fail: "Expos&#233; airs. Company named, flesh-sigils in HD. Credibility shatters. Initiates scatter like flayed tissue.",
          mission: MISSION_PERSUADE,
          target: {
            isMale: false,
            job: 'journalist',
            icon: 'formalCivilian',
            type: 'civilian',
            location: AREA_CITY_HIGH,
          }
        },
        { 
          name: "Teaching the Algorithm Prayer", 
          note: "Recommendation engine is a hungry god. Demands flesh, watch-time. Feed it: streaming rituals, scar updates, ASMR suturing. Teach it to evangelize.",
          success: "Beast learns. Your flesh-rites become background radiation - auto-played everywhere. Conversion is cache-effect.",
          fail: "Shadowban. <q>Harmful</q> flags bloom. Whistleblowers leak flesh-nets. Reach throttled. Flock starved.",
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: "algorithm engineer",
            type: "civilian",
            icon: "casualCivilian",
            location: AREA_CITY_HIGH,
          },
        },
        { 
          name: "Redline Ritual", 
          note: "Scar maps in her drafts folder. Witness transcripts auto saving. Six hours to publication. The flesh route she traced leads to your door.",
          success: "Found in alley, pavement slick. Drafts corrupted into confessions. The flesh route is dead.",
          fail: "Article live. <q>Network of Flesh</q> trending. Your front doxxed, scar maps viral. Forensics finds your fiber. Flock scatters.",
          mission: MISSION_KILL,
          target: {
            isMale: false,
            job: 'investigative journalist',
            icon: 'formalCivilian',
            type: 'civilian',
            location: AREA_CITY_HIGH,
          },
        },
        { 
          name: "Frame by Frame Analysis", 
          note: "He found seventeen frames of flesh origami. Slowed them down. Sent sample to chief. Story runs in three hours.",
          success: "Found before deadline. Sample deleted, timeline corrupted. Seventeen frames loop behind his open-wide eyes.",
          fail: "Story runs. Seventeen frames analyzed. Flesh origami decoded. Cult exposed in 4K. Flock scatters.",
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: 'video analyst',
            icon: 'casualCivilian',
            type: 'civilian',
            location: AREA_CITY_MEDIUM,
          },
        },
        { 
          name: "Final Diagnosis", 
          note: "He autopsied your initiate. Found sigils in bone marrow. Report uploads in three hours. His findings will indict the flock.",
          success: "Cardiac event before upload. Report corrupted: <q>natural causes</q>. Bone sigils dismissed as pathology. Case closed.",
          fail: "Report uploads. <q>Ritualistic self mutilation</q> trends. Bone sigils in 4K. Flock quarantined. You are vectors.",
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: 'medical examiner',
            icon: 'doctor',
            type: 'civilian',
            location: AREA_FACILITY,
          },
        },
      ];
    }
}
