// data for generic corporate profane ordeals
package cult.ordeals.profane;

class CorpoConst extends OrdealConst
{
  public function new()
    {
      super();
      infos = [
        {
          name: N("Quarterly Flesh Dividend"),
          note: N("CFO reviews projections. Red ink bleeds into her spreadsheets. Our shell company offers merger: assets in marrow, returns in devotion. Board meeting in two hours."),
          success: T("She signs. Calls it <q>vertical integration.</q> Pension funds now tithe to the flock. Shareholders receive communion."),
          fail: T("Due diligence uncovers the processing wing. SEC flags transactions. Shell company dissolved. Assets frozen in formaldehyde."),
          mission: MISSION_PERSUADE,
          target: {
            isMale: false,
            job: N("chief financial officer"),
            type: "smiler",
            icon: "smiler",
            location: AREA_CORP,
          },
        },
        {
          name: N("Performance Review in Viscera"),
          note: N("Middle manager drowns in metrics. His team bleeds productivity. We offer alternative KPIs: scars per quarter, devotion per capita. Promotion review tomorrow."),
          success: T("He restructures department around flesh principles. Calls it <q>organic growth.</q> His direct reports genuflect at standup."),
          fail: T("HR flags behavioral changes. Mandatory counseling. His access revoked. The org chart heals without him."),
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: N("department manager"),
            type: "corpo",
            icon: "corpo",
            location: AREA_CORP,
          },
        },
        {
          name: N("Synergy of the Opened Vein"),
          note: N("VP of acquisitions hunts startups. We pitch: biotech firm specializing in <q>regenerative tissue.</q> Her bonus depends on deal flow. Pitch meeting at noon."),
          success: T("Term sheet signed. Our front company absorbed into portfolio. R&#38;D budget now funds the sacrament. She calls it <q>disruptive.</q>"),
          fail: T("Technical due diligence fails. Lab samples flagged as human origin. Deal collapses. Compliance opens investigation."),
          mission: MISSION_PERSUADE,
          target: {
            isMale: false,
            job: N("vice president"),
            type: "smiler",
            icon: "smiler",
            location: AREA_CORP,
          },
        },
        {
          name: N("Audit Trail in Marrow"),
          note: N("Internal auditor found discrepancies. Shell company invoices trace to our processing facility. His report uploads at market close. Corner office, fourteenth floor."),
          success: T("Found in the office, spreadsheet open. Cardiac event, they say. Report corrupted. The numbers balance in blood."),
          fail: T("Report uploads. Forensic accountants descend. Paper trail leads to the sublevel. Assets seized."),
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: N("internal auditor"),
            type: "corpo",
            icon: "corpo",
            location: AREA_CORP,
          },
        },
        {
          name: N("Whistleblower Severance"),
          note: N("Compliance officer compiled dossier. Photos of the basement ritual. Anonymous tip scheduled for morning. She works late, alone."),
          success: T("Office found empty. Resignation letter on desk, typed on company letterhead. Dossier feeds the shredder."),
          fail: T("Tip reaches regulators. Raid at dawn. Basement photographed in fluorescent light. Flock scattered."),
          mission: MISSION_KILL,
          target: {
            isMale: false,
            job: N("compliance officer"),
            type: "smiler",
            icon: "smiler",
            location: AREA_CORP,
          },
        },
        {
          name: N("Hostile Takeover, Literal"),
          note: N("Rival executive discovered our subsidiary's true purpose. Leverage for hostile bid. Meeting with board tomorrow. His driver takes the parking garage route."),
          success: T("Found on office floor, seventeenth story. Window open, wind howling. Board meeting proceeds without objection."),
          fail: T("He presents evidence. Board votes unanimously. Our subsidiary divested. The flock loses its corporate veil."),
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: N("executive director"),
            type: "smiler",
            icon: "smiler",
            location: AREA_CORP,
          },
        },
        { 
          name: N("Executive Function"),
          note: N("He holds kill switch for bot farms. Noon board meeting. Server logs hold your fingerprints, encoded in scar tissue."),
          success: T("Cardiac arrest before noon. Logs wiped, switch never thrown. Bot farms breathe. Your prints fade to ghost."),
          fail: T("Board meeting starts. Evidence streams: bot farms, scar codes. Kill switch thrown. Reach zero. You are shadows."),
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: N("lead programmer"),
            type: "civilian",
            icon: "hacker",
            location: AREA_CORP,
          },
        },
      ];
    }
}
