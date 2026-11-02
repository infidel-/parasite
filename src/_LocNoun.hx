// what an entity hands l10n.Loc for a {name:form} placeholder (returned by its getLocNoun())
typedef _LocNoun = {
  var key: String;          // English noun ('police officer'), proper name or phrase key
  var kind: _LocNounKind;   // noun, proper name or fixed phrase
  var gender: String;       // natural gender of the entity: 'm', 'f' or 'n' (it)
}
