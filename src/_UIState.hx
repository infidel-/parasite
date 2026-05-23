// available UI states

enum abstract _UIState(String) to String from String
{
  var UISTATE_DEFAULT = 'UISTATE_DEFAULT'; // default
  var UISTATE_GOALS = 'UISTATE_GOALS'; // goals window open
  var UISTATE_EVOLUTION = 'UISTATE_EVOLUTION'; // evolution window open
  var UISTATE_DEBUG = 'UISTATE_DEBUG'; // debug window open
  var UISTATE_TIMELINE = 'UISTATE_TIMELINE'; // timeline window open
  var UISTATE_LOG = 'UISTATE_LOG'; // log window open
  var UISTATE_CONSOLE = 'UISTATE_CONSOLE'; // console open
  var UISTATE_MESSAGE = 'UISTATE_MESSAGE'; // important message window open
  var UISTATE_FINISH = 'UISTATE_FINISH'; // game over window
  var UISTATE_OPTIONS = 'UISTATE_OPTIONS'; // options window
  var UISTATE_BODY = 'UISTATE_BODY'; // new body window
  var UISTATE_MAINMENU = 'UISTATE_MAINMENU'; // main menu
  var UISTATE_NEWGAME = 'UISTATE_NEWGAME'; // new game menu
  var UISTATE_SPOON = 'UISTATE_SPOON'; // spoon mode options
  var UISTATE_PEDIA = 'UISTATE_PEDIA'; // pedia windw
  var UISTATE_OVUM = 'UISTATE_OVUM'; // parthenogenesis settings
  var UISTATE_ABOUT = 'UISTATE_ABOUT'; // about window
  var UISTATE_CULT = 'UISTATE_CULT'; // cult details window

  var UISTATE_DIFFICULTY = 'UISTATE_DIFFICULTY'; // difficulty setting
  var UISTATE_CHOICE = 'UISTATE_CHOICE'; // occasio choice window
  var UISTATE_YESNO = 'UISTATE_YESNO'; // yes/no dialog window
  var UISTATE_DOCUMENT = 'UISTATE_DOCUMENT'; // text document window
  var UISTATE_PRESETS = 'UISTATE_PRESETS'; // presets window
  var UISTATE_MODS = 'UISTATE_MODS'; // mods management window
}
