// ordeal info type
typedef _OrdealInfo = {
  var name: String;
  var note: String;
  var success: String;
  var fail: String;
  var mission: _OrdealMissionType;
  var ?target: _MissionTarget;
  var ?combat: _CombatMissionInfo;
}
