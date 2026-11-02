// imported into every module under src/: the localization string markers (see l10n.Loc). the
// package is l10n, not loc: the T macro expands to l10n.Loc.tr(...), and a local variable named loc
// (common in this code) would shadow a package of that name
import l10n.Loc.T;
import l10n.Loc.N;
