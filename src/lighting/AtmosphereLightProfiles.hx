package lighting;

// shared atmosphere light presets for object emitters
class AtmosphereLightProfiles
{
  public static var OBJECT_LIGHT_RADIUS_LARGE = 2.4;
  public static var OBJECT_LIGHT_INTENSITY_PALE = 0.80;

  public static var HABITAT_WATCHER: _AtmosphereLightMeta = {
    radiusTiles: OBJECT_LIGHT_RADIUS_LARGE,
    intensity: OBJECT_LIGHT_INTENSITY_PALE,
    tintR: 255,
    tintG: 120,
    tintB: 120,
  };

  public static var HABITAT_BIOMINERAL: _AtmosphereLightMeta = {
    radiusTiles: OBJECT_LIGHT_RADIUS_LARGE,
    intensity: OBJECT_LIGHT_INTENSITY_PALE,
    tintR: 36,
    tintG: 155,
    tintB: 12,
  };

  public static var HABITAT_ASSIMILATION_CAVITY: _AtmosphereLightMeta = {
    radiusTiles: OBJECT_LIGHT_RADIUS_LARGE,
    intensity: OBJECT_LIGHT_INTENSITY_PALE,
    tintR: 96,
    tintG: 16,
    tintB: 155,
  };

  public static var HABITAT_PRESERVATOR: _AtmosphereLightMeta = {
    radiusTiles: OBJECT_LIGHT_RADIUS_LARGE,
    intensity: OBJECT_LIGHT_INTENSITY_PALE,
    tintR: 4,
    tintG: 88,
    tintB: 155,
  };
}
