// data for generic political profane ordeals
package cult.ordeals.profane;

class PoliticalConst extends OrdealConst
{
  public function new()
    {
      super();
      infos = [
        {
          name: N("Fleshwhisper in the Cloakroom"),
          note: N("A junior legislator drifts through marble halls, briefcase heavy with dead paper. Show him how living flesh strips pretense, how sinew writes truer laws. The caucus need not know what nourishes his votes."),
          success: T("He files the amendment. His smile tastes of iron."),
          fail: T("He flees. The Capitol police receive an anonymous tip about <q>flesh cultists</q>."),
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: N("aide"),
            type: "civilian",
            icon: "formalCivilian",
            location: AREA_CITY_HIGH
          }
        },
        {
          name: N("Lobbyist's Crimson Sacrament"),
          note: N("She trades favors between suites and chambers, loyalty purchased hourly. Offer her a taste that cannot be bought. The flesh remembers what money forgets."),
          success: T("She redirects the accounts. Her laughter carries new hunger."),
          fail: T("She calls security. <q>Psychotic cannibals,</q> her email reads."),
          mission: MISSION_PERSUADE,
          target: {
            isMale: false,
            job: N("lobbyist"),
            type: "corpo",
            icon: "corpo",
            location: AREA_CORP
          }
        },
        {
          name: N("Municipal Vein Revelation"),
          note: N("The alderman dispenses patronage like communion wafers, dry and crumbling. Invite him to a sacrament where power flows from veins, not votes. His constituents will notice the hunger in his eyes."),
          success: T("He rezones the warehouse district. His hands tremble with renewed purpose."),
          fail: T("He alerts the mayor. <q>They tried to make me eat human flesh,</q> he testifies."),
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: N("alderman"),
            type: "civilian",
            icon: "formalCivilian",
            location: AREA_CITY_MEDIUM
          }
        },
        {
          name: N("The Caucus of Wet Hands"),
          note: N("A councilwoman speaks of reform. Her palms have never touched the membrane. She must learn what consensus truly means."),
          success: T("She signs with trembling fingers, ink mixing with something redder."),
          fail: T("Her office door remains closed. The vote proceeds without our voice."),
          mission: MISSION_PERSUADE,
          target: {
            isMale: false,
            job: N("councilwoman"),
            type: "civilian",
            icon: "formalCivilian",
            location: AREA_CITY_HIGH,
          },
        },
        {
          name: N("Flesh Quorum at the Statehouse"),
          note: N("The budget committee convenes at midnight. One member must carry our amendment written on vellum of particular origin."),
          success: T("The motion passes unanimously. No one remembers who proposed it."),
          fail: T("Parliamentary procedure buries our clause. The old laws persist."),
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: N("budget analyst"),
            type: "civilian",
            icon: "formalCivilian",
            location: AREA_CITY_HIGH,
          },
        },
        {
          name: N("The Lobbyist&#39;s Communion"),
          note: N("He trades in favors and handshakes. We offer him a grip that leaves residue, a partnership sealed in sinew."),
          success: T("His client list now includes names that writhe when spoken aloud."),
          fail: T("He chooses cleaner money. Our interests remain unrepresented."),
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: N("lobbyist"),
            type: "corpo",
            icon: "corpo",
            location: AREA_CORP,
          },
        },
        {
          name: N("The Whistleblower&#39;s Silence"),
          note: N("She has documents. Names of flesh patrons in high office. Her testimony before the committee is scheduled for dawn."),
          success: T("Found in an alley, throat opened like an envelope. Documents scattered, illegible with rain and red."),
          fail: T("She testifies. Names read into record. Patrons exposed. The flock loses its shepherds in high places."),
          mission: MISSION_KILL,
          target: {
            isMale: false,
            job: N("government auditor"),
            type: "civilian",
            icon: "formalCivilian",
            location: AREA_CITY_HIGH,
          },
        },
        {
          name: N("Veto in Viscera"),
          note: N("The senator drafts legislation against unlicensed medical practices. His pen threatens our surgeries, our sacraments."),
          success: T("Aide found in an alley behind the capitol. The bill dies with him, unsigned, unstained."),
          fail: T("Bill passes. Clinics raided. Surgical tools confiscated. The flesh work goes underground, starving."),
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: N("senator aide"),
            type: "civilian",
            icon: "formalCivilian",
            location: AREA_CITY_HIGH,
          },
        },
        {
          name: N("The Inspector&#39;s Final Report"),
          note: N("He found the basement. Photographed the tables. His report uploads to federal servers at midnight."),
          success: T("Cardiac event in an alley. Camera destroyed. Report corrupted. The basement remains our secret."),
          fail: T("Report uploads. Federal agents descend. The basement is emptied, catalogued, condemned."),
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: N("building inspector"),
            type: "civilian",
            icon: "casualCivilian",
            location: AREA_CITY_MEDIUM,
          },
        },
      ];
    }
}
