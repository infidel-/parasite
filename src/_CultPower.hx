@:structInit
class _CultPower extends _SaveObject
{
  public var combat: Int;
  public var media: Int;
  public var lawfare: Int;
  public var corporate: Int;
  public var political: Int;
  public var occult: Int;
  public var money: Int;

  public function new(combat: Int, media: Int, lawfare: Int, corporate: Int, political: Int, occult: Int, money: Int)
    {
      this.combat = combat;
      this.media = media;
      this.lawfare = lawfare;
      this.corporate = corporate;
      this.political = political;
      this.occult = occult;
      this.money = money;
    }

// get field value by name
  public function get(power: String): Int
    {
      switch (power)
        {
          case 'combat': return combat;
          case 'media': return media;
          case 'lawfare': return lawfare;
          case 'corporate': return corporate;
          case 'political': return political;
          case 'occult': return occult;
          case 'money': return money;
          default: return 0;
        }
    }

// increment field value by name
  public function inc(power: String, ?val: Int = 1): Void
    {
      switch (power)
        {
          case 'combat': combat += val;
          case 'media': media += val;
          case 'lawfare': lawfare += val;
          case 'corporate': corporate += val;
          case 'political': political += val;
          case 'occult': occult += val;
          case 'money': money += val;
        }
    }

// decrement field value by name
  public function dec(power: String, ?val: Int = 1): Void
    {
      switch (power)
        {
          case 'combat': combat -= val;
          case 'media': media -= val;
          case 'lawfare': lawfare -= val;
          case 'corporate': corporate -= val;
          case 'political': political -= val;
          case 'occult': occult -= val;
          case 'money': money -= val;
        }
    }

// static arrays for power names (excluding occult and money)
  public static var names = ['combat', 'media', 'lawfare', 'corporate', 'political'];
  public static var namesCap = ['Combat', 'Media', 'Lawfare', 'Corporate', 'Political'];
  public static var namesUpper = ['COMBAT', 'MEDIA', 'LAWFARE', 'CORPORATE', 'POLITICAL'];
}
