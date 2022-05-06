// player variables
package game;

@:structInit class PlayerVars extends _SaveObject
{
  // GUI and initial progression flags (set on goal completion)
  public var inventoryEnabled: Bool;
  public var objectsEnabled: Bool;
  public var skillsEnabled: Bool;
  public var timelineEnabled: Bool;
  public var organsEnabled: Bool;
  public var npcEnabled: Bool; // npc spawn enabled?
  public var searchEnabled: Bool; // computer search info enabled?
  public var habitatsLeft: Int; // max total amount of habitats

  public var evolutionEnergyPerTurn: Int; // energy spent per turn during evolution
  public var evolutionEnergyPerTurnMicrohabitat: Int; // -- in microhabitat
  public var organGrowthEnergyPerTurn: Int; // energy spent per turn when growing organs
  public var organGrowthPointsPerTurn: Int; // organ growth points per turn

  public var areaEnergyPerTurn: Int; // area: energy spent per turn without a host
  public var regionEnergyPerTurn: Int; // region: energy cost per turn without a host
  public var startHealth: Int; // starting parasite health
  public var startEnergy: Int; // starting parasite energy
  public var maxEnergy: Int; // max parasite energy
  public var listenRadius: Int; // player listen radius
  public var losEnabled: Bool; // LOS checks enabled?
  public var invisibilityEnabled: Bool; // player invisibility enabled?
  public var godmodeEnabled: Bool; // player godmode enabled?

  public function new(
    inventoryEnabled,
    objectsEnabled,
    skillsEnabled,
    timelineEnabled,
    organsEnabled,
    npcEnabled,
    searchEnabled,
    habitatsLeft,
    evolutionEnergyPerTurn,
    evolutionEnergyPerTurnMicrohabitat,
    organGrowthEnergyPerTurn,
    organGrowthPointsPerTurn,
    areaEnergyPerTurn,
    regionEnergyPerTurn,
    startHealth,
    startEnergy,
    maxEnergy,
    listenRadius,
    losEnabled,
    invisibilityEnabled,
    godmodeEnabled)
    {
      this.inventoryEnabled = inventoryEnabled;
      this.objectsEnabled = objectsEnabled;
      this.skillsEnabled = skillsEnabled;
      this.timelineEnabled = timelineEnabled;
      this.organsEnabled = organsEnabled;
      this.npcEnabled = npcEnabled;
      this.searchEnabled = searchEnabled;
      this.habitatsLeft = habitatsLeft;
      this.evolutionEnergyPerTurn = evolutionEnergyPerTurn;
      this.evolutionEnergyPerTurnMicrohabitat = evolutionEnergyPerTurnMicrohabitat;
      this.organGrowthEnergyPerTurn = organGrowthEnergyPerTurn;
      this.organGrowthPointsPerTurn = organGrowthPointsPerTurn;
      this.areaEnergyPerTurn = areaEnergyPerTurn;
      this.regionEnergyPerTurn = regionEnergyPerTurn;
      this.startHealth = startHealth;
      this.startEnergy = startEnergy;
      this.maxEnergy = maxEnergy;
      this.listenRadius = listenRadius;
      this.losEnabled = losEnabled;
      this.invisibilityEnabled = invisibilityEnabled;
      this.godmodeEnabled = godmodeEnabled;
    }
}
