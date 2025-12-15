// data for generic corporate profane ordeals
package cult.ordeals.profane;

class CorpoConst extends OrdealConst
{
  public function new()
    {
      super();
      infos = [
        {
          name: "Quarterly Flesh Dividend",
          note: "CFO reviews projections. Red ink bleeds into her spreadsheets. Our shell company offers merger: assets in marrow, returns in devotion. Board meeting in two hours.",
          success: "She signs. Calls it <q>vertical integration.</q> Pension funds now tithe to the flock. Shareholders receive communion.",
          fail: "Due diligence uncovers the processing wing. SEC flags transactions. Shell company dissolved. Assets frozen in formaldehyde.",
          mission: MISSION_PERSUADE,
          target: {
            isMale: false,
            job: "chief financial officer",
            type: "smiler",
            icon: "smiler",
            location: AREA_CORP,
          },
        },
        {
          name: "Performance Review in Viscera",
          note: "Middle manager drowns in metrics. His team bleeds productivity. We offer alternative KPIs: scars per quarter, devotion per capita. Promotion review tomorrow.",
          success: "He restructures department around flesh principles. Calls it <q>organic growth.</q> His direct reports genuflect at standup.",
          fail: "HR flags behavioral changes. Mandatory counseling. His access revoked. The org chart heals without him.",
          mission: MISSION_PERSUADE,
          target: {
            isMale: true,
            job: "department manager",
            type: "corpo",
            icon: "corpo",
            location: AREA_CORP,
          },
        },
        {
          name: "Synergy of the Opened Vein",
          note: "VP of acquisitions hunts startups. We pitch: biotech firm specializing in <q>regenerative tissue.</q> Her bonus depends on deal flow. Pitch meeting at noon.",
          success: "Term sheet signed. Our front company absorbed into portfolio. R&#38;D budget now funds the sacrament. She calls it <q>disruptive.</q>",
          fail: "Technical due diligence fails. Lab samples flagged as human origin. Deal collapses. Compliance opens investigation.",
          mission: MISSION_PERSUADE,
          target: {
            isMale: false,
            job: "vice president",
            type: "smiler",
            icon: "smiler",
            location: AREA_CORP,
          },
        },
        {
          name: "Audit Trail in Marrow",
          note: "Internal auditor found discrepancies. Shell company invoices trace to our processing facility. His report uploads at market close. Corner office, fourteenth floor.",
          success: "Found in the office, spreadsheet open. Cardiac event, they say. Report corrupted. The numbers balance in blood.",
          fail: "Report uploads. Forensic accountants descend. Paper trail leads to the sublevel. Assets seized.",
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: "internal auditor",
            type: "corpo",
            icon: "corpo",
            location: AREA_CORP,
          },
        },
        {
          name: "Whistleblower Severance",
          note: "Compliance officer compiled dossier. Photos of the basement ritual. Anonymous tip scheduled for morning. She works late, alone.",
          success: "Office found empty. Resignation letter on desk, typed on company letterhead. Dossier feeds the shredder.",
          fail: "Tip reaches regulators. Raid at dawn. Basement photographed in fluorescent light. Flock scattered.",
          mission: MISSION_KILL,
          target: {
            isMale: false,
            job: "compliance officer",
            type: "smiler",
            icon: "smiler",
            location: AREA_CORP,
          },
        },
        {
          name: "Hostile Takeover, Literal",
          note: "Rival executive discovered our subsidiary's true purpose. Leverage for hostile bid. Meeting with board tomorrow. His driver takes the parking garage route.",
          success: "Found on office floor, seventeenth story. Window open, wind howling. Board meeting proceeds without objection.",
          fail: "He presents evidence. Board votes unanimously. Our subsidiary divested. The flock loses its corporate veil.",
          mission: MISSION_KILL,
          target: {
            isMale: true,
            job: "executive director",
            type: "smiler",
            icon: "smiler",
            location: AREA_CORP,
          },
        },
      ];
    }
}
