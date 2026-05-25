// evolution improvement ids
// enum abstract over String: builtin IMP_* constants stay usable in engine
// code (compile-time checked, autocompleted), while the runtime value is a
// plain String so mods can register new improvement ids at runtime and so
// persisted save fields hold bare strings (see Loader.initEnum migration).
enum abstract _Improv(String) to String from String
{
  var IMP_HOST_RELEASE = 'IMP_HOST_RELEASE';
  var IMP_DECAY_ACCEL = 'IMP_DECAY_ACCEL';
  var IMP_CAMO_LAYER = 'IMP_CAMO_LAYER'; // special
  var IMP_DOPAMINE = 'IMP_DOPAMINE'; // special
  var IMP_BRAIN_PROBE = 'IMP_BRAIN_PROBE'; // special
  var IMP_PROT_COVER = 'IMP_PROT_COVER';
  var IMP_MUSCLE = 'IMP_MUSCLE';
  var IMP_WOUND_REGEN = 'IMP_WOUND_REGEN';
  var IMP_HEALTH = 'IMP_HEALTH';
  var IMP_ENERGY = 'IMP_ENERGY';
  var IMP_HARDEN_GRIP = 'IMP_HARDEN_GRIP';
  var IMP_ATTACH = 'IMP_ATTACH';
  var IMP_REINFORCE = 'IMP_REINFORCE';
  var IMP_ACID_SPIT = 'IMP_ACID_SPIT';
  var IMP_SLIME_SPIT = 'IMP_SLIME_SPIT';
  var IMP_PARALYSIS_SPIT = 'IMP_PARALYSIS_SPIT';
  var IMP_PANIC_GAS = 'IMP_PANIC_GAS';
  var IMP_PARALYSIS_GAS = 'IMP_PARALYSIS_GAS';
  var IMP_MICROHABITAT = 'IMP_MICROHABITAT'; // special
  var IMP_BIOMINERAL = 'IMP_BIOMINERAL'; // special
  var IMP_ASSIMILATION = 'IMP_ASSIMILATION'; // special
  var IMP_WATCHER = 'IMP_WATCHER'; // special
  var IMP_PRESERVATOR = 'IMP_PRESERVATOR'; // special
  var IMP_OVUM = 'IMP_OVUM'; // special
  var IMP_FALSE_MEMORIES = 'IMP_FALSE_MEMORIES'; // special
  var IMP_ENGRAM = 'IMP_ENGRAM'; // special
}
