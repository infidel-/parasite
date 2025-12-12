package cult.ordeals.profane;

class OrdealConst
{
  var infos: Array<_OrdealInfo>;

  public function new()
    {
      infos = [];
    }

// get random ordeal info index
  public function getRandom(): Int
    {
      return Std.random(infos.length);
    }

// return ordeal info by index
  public function getInfo(index: Int): _OrdealInfo
    {
      if (index < 0 || index >= infos.length)
        return infos[0]; // fallback to first info if index is invalid
      return infos[index];
    }

// return all ordeal infos
  public function getInfos(): Array<_OrdealInfo>
    {
      return infos;
    }
}
