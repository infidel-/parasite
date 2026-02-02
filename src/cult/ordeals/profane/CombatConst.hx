// data for generic combat profane ordeals
package cult.ordeals.profane;

class CombatConst extends OrdealConst
{
// define combat profane ordeals
  public function new()
    {
      super();
      // define combat ordeal entries
      infos = [
        {
          name: "Unaussprechliche Head",
          note: "The Unaussprechliche Kult keeps its head in a corporate suite, flanked by two armed guards. Strike together or die alone.",
          success: "Head and guards fall. The kult fractures, rituals collapsing into static. The suite goes dark.",
          fail: "You are repelled. The head slips away, guards calling backup. The Unaussprechliche Kult grows bold.",
          mission: MISSION_COMBAT,
          combatTemplate: TARGET_WITH_GUARDS,
          targets: [
            {
              isMale: true,
              job: "cult head",
              type: "smiler",
              icon: "smiler",
              location: AREA_CORP,
              helpAvailable: false,
            },
            {
              isMale: true,
              job: "security guard",
              type: "security",
              icon: "security",
              location: AREA_CORP,
              helpAvailable: false,
            },
            {
              isMale: true,
              job: "security guard",
              type: "security",
              icon: "security",
              location: AREA_CORP,
              helpAvailable: false,
            }
          ]
        }
      ];
    }
}
