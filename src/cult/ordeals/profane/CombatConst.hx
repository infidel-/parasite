// data for generic combat profane ordeals
package cult.ordeals.profane;

class CombatConst extends OrdealConst
{
// define combat profane ordeals
  public function new()
    {
      super();
      // define combat ordeal entries by source class
      infos = [
        CorpoCult.getInfo(),
        BumCult.getInfo(),
        ThugCult.getInfo(),
        ProstituteCult.getInfo(),
        SewerSummoning.getInfo(),
        LabCloning.getInfo(),
      ];
    }
}
