// data for generic political profane ordeals
package cult.ordeals.profane;

class PoliticalConst extends OrdealConst
{
  public function new()
    {
      super();
      infos = [
        {
          name: "Fleshwhisper in the Cloakroom",
          note: "A junior legislator drifts through marble halls, briefcase heavy with dead paper. Show him how living flesh strips pretense, how sinew writes truer laws. The caucus need not know what nourishes his votes.",
          success: "He files the amendment. His smile tastes of iron.",
          fail: "He flees. The Capitol police receive an anonymous tip about <q>flesh cultists</q>.",
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: "aide",
            type: "civilian",
            icon: "formalCivilian",
            location: AREA_CITY_HIGH
          }
        },
        {
          name: "Lobbyist's Crimson Sacrament",
          note: "She trades favors between suites and chambers, loyalty purchased hourly. Offer her a taste that cannot be bought. The flesh remembers what money forgets.",
          success: "She redirects the accounts. Her laughter carries new hunger.",
          fail: "She calls security. <q>Psychotic cannibals,</q> her email reads.",
          mission: MISSION_PERSUADE,
          target: {
            isMale: false,
            job: "lobbyist",
            type: "corpo",
            icon: "corpo",
            location: AREA_CORP
          }
        },
        {
          name: "Municipal Vein Revelation",
          note: "The alderman dispenses patronage like communion wafers, dry and crumbling. Invite him to a sacrament where power flows from veins, not votes. His constituents will notice the hunger in his eyes.",
          success: "He rezones the warehouse district. His hands tremble with renewed purpose.",
          fail: "He alerts the mayor. <q>They tried to make me eat human flesh,</q> he testifies.",
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: "alderman",
            type: "civilian",
            icon: "formalCivilian",
            location: AREA_CITY_MEDIUM
          }
        },
        {
          name: "The Caucus of Wet Hands",
          note: "A councilwoman speaks of reform. Her palms have never touched the membrane. She must learn what consensus truly means.",
          success: "She signs with trembling fingers, ink mixing with something redder.",
          fail: "Her office door remains closed. The vote proceeds without our voice.",
          mission: MISSION_PERSUADE,
          target: {
            isMale: false,
            job: "councilwoman",
            type: "civilian",
            icon: "formalCivilian",
            location: AREA_CITY_HIGH,
          },
        },
        {
          name: "Flesh Quorum at the Statehouse",
          note: "The budget committee convenes at midnight. One member must carry our amendment written on vellum of particular origin.",
          success: "The motion passes unanimously. No one remembers who proposed it.",
          fail: "Parliamentary procedure buries our clause. The old laws persist.",
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: "budget analyst",
            type: "civilian",
            icon: "formalCivilian",
            location: AREA_CITY_HIGH,
          },
        },
        {
          name: "The Lobbyist&#39;s Communion",
          note: "He trades in favors and handshakes. We offer him a grip that leaves residue, a partnership sealed in sinew.",
          success: "His client list now includes names that writhe when spoken aloud.",
          fail: "He chooses cleaner money. Our interests remain unrepresented.",
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: "lobbyist",
            type: "corpo",
            icon: "corpo",
            location: AREA_CORP,
          },
        },
        {
          name: "The Whistleblower&#39;s Silence",
          note: "She has documents. Names of flesh patrons in high office. Her testimony before the committee is scheduled for dawn.",
          success: "Found in an alley, throat opened like an envelope. Documents scattered, illegible with rain and red.",
          fail: "She testifies. Names read into record. Patrons exposed. The flock loses its shepherds in high places.",
          mission: MISSION_KILL,
          target: {
            isMale: false,
            job: "government auditor",
            type: "civilian",
            icon: "formalCivilian",
            location: AREA_CITY_HIGH,
          },
        },
        {
          name: "Veto in Viscera",
          note: "The senator drafts legislation against unlicensed medical practices. His pen threatens our surgeries, our sacraments.",
          success: "Aide found in an alley behind the capitol. The bill dies with him, unsigned, unstained.",
          fail: "Bill passes. Clinics raided. Surgical tools confiscated. The flesh work goes underground, starving.",
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: "senator aide",
            type: "civilian",
            icon: "formalCivilian",
            location: AREA_CITY_HIGH,
          },
        },
        {
          name: "The Inspector&#39;s Final Report",
          note: "He found the basement. Photographed the tables. His report uploads to federal servers at midnight.",
          success: "Cardiac event in an alley. Camera destroyed. Report corrupted. The basement remains our secret.",
          fail: "Report uploads. Federal agents descend. The basement is emptied, catalogued, condemned.",
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: "building inspector",
            type: "civilian",
            icon: "casualCivilian",
            location: AREA_CITY_MEDIUM,
          },
        },
      ];
    }
}
