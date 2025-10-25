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
}
