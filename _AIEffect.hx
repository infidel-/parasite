// AI effect

typedef _AIEffect =
{
  type: _AIEffectType, // effect type
  points: Int, // effect strength
  ?isTimer: Bool // effect is time-based? (-1 point/turn) (default: false)
}
