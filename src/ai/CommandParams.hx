// command params for follower commands
package ai;

enum CommandType
{
  CMD_NONE;
  CMD_ATTACK;
  CMD_LEAVE_AREA;
}

class CommandParams extends _SaveObject
{
  public var type: CommandType;
  public var attackTargetID: Int;
  public var leaveAreaTurns: Int;

// create command params
  public function new()
    {
      init();
    }

// set default command params
  public function init()
    {
      type = CMD_NONE;
      attackTargetID = -1;
      leaveAreaTurns = 0;
    }
}
