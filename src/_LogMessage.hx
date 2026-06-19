// log message

@:structInit class _LogMessage
{
  public var msg: String;
  public var col: _TextColor;
  public var cnt: Int;
  public var turn: Int; // game turn this message was logged on (for the log ledger)

  public function new(msg, col, cnt, turn = 0)
    {
      this.msg = msg;
      this.col = col;
      this.cnt = cnt;
      this.turn = turn;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }
}
