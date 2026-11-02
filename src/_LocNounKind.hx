// how l10n.Loc renders a noun placeholder
enum _LocNounKind
{
  LOC_NOUN;   // common noun: looked up in the language noun table, gets articles/forms
  LOC_NAME;   // proper name: never translated, never gets an article
  LOC_PHRASE; // fixed phrase ('your host'): translated with Loc.tr, never gets an article
}
