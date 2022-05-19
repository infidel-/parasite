// log message

@:structInit class _LogMessage
{
  public var msg: String;
  public var col: _TextColor;
  public var cnt: Int;

  public function new(msg, col, cnt)
    {
      this.msg = msg;
      this.col = col;
      this.cnt = cnt;
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
