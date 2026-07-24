// combat mission info
typedef _CombatMissionInfo = {
  var template: _CombatMissionTemplate;
  var targets: Array<_CombatMissionTargetInfo>;
  // optional: object type to muster the target cluster next to (e.g. 'burning_barrel');
  // null/absent -> cluster spawns at a random unseen tile as before
  var ?spawnNearType: String;
}
