// available UI states

enum _UIState {
  UISTATE_DEFAULT; // default
  UISTATE_GOALS; // goals window open
  UISTATE_EVOLUTION; // evolution window open
  UISTATE_INVENTORY; // LEGACY: inventory window open
  UISTATE_SKILLS; // LEGACY: skills window open
  UISTATE_ORGANS; // LEGACY: organs window open
  UISTATE_DEBUG; // debug window open
  UISTATE_TIMELINE; // timeline window open
  UISTATE_LOG; // log window open
  UISTATE_CONSOLE; // console open
  UISTATE_MESSAGE; // important message window open
  UISTATE_FINISH; // game over window
  UISTATE_OPTIONS; // options window
  UISTATE_BODY; // new body window
  UISTATE_MAINMENU; // main menu

  UISTATE_DIFFICULTY; // difficulty setting
  UISTATE_YESNO; // yes/no dialog window
  UISTATE_DOCUMENT; // text document window
}
