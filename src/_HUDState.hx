// hud states
enum abstract _HUDState(String) to String from String
{
  var HUD_DEFAULT = 'HUD_DEFAULT';
  var HUD_CHAT = 'HUD_CHAT';
  var HUD_CONVERSE_MENU = 'HUD_CONVERSE_MENU';
  var HUD_COMMAND_MENU = 'HUD_COMMAND_MENU';
  var HUD_TARGETING = 'HUD_TARGETING';
  var HUD_BASE_BUILDING = 'HUD_BASE_BUILDING';
  var HUD_PICKUP_MENU = 'HUD_PICKUP_MENU'; // ground-items submenu (multiple pickups on the tile)
}
