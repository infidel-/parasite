// trait info list

package const;

class TraitsConst
{
// return info by id
  public static function getInfo(id: _AITraitType): _TraitInfo
    {
      for (ii in traits)
        if (ii.id == id)
          return ii;

      throw 'No such trait: ' + id;
      return null;
    }


// trait infos
  public static var traits: Array<_TraitInfo> = [
    {
      id: TRAIT_DRUG_ADDICT,
      name: 'drug addict',
      note: 'Addicted to drugs.'
    },
    {
      id: TRAIT_ASSIMILATED,
      name: 'assimilated',
      note: 'Has been assimilated.'
    },
  ];
}


// trait info

typedef _TraitInfo =
{
  id: _AITraitType, // trait id
  name: String, // trait name
  note: String, // trait note
}
