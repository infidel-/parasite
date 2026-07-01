// payload for the YesNo confirm dialog (ui.YesNo.setParams)
typedef _YesNoParams = {
  var text: String;              // prompt body (may contain html)
  var func: Bool -> Void;        // result handler (true = yes, false = no)
  @:optional var sub: String;    // optional sub-detail line under the prompt
  @:optional var danger: Bool;   // red danger styling + "Confirm exit" kicker
  @:optional var kicker: String; // kicker text override
  @:optional var back: _UIState; // state to return to on close (default DEFAULT)
}
