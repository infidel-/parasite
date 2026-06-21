// game finish (game over) parameters typedef
typedef _FinishParams = {
  // 'win' | 'lose'
  var result: String;
  // death-key (lose) or literal prose (win)
  var text: String;
  // optional image name without 'img/' prefix or extension, e.g. 'event/death'
  @:optional var img: String;
  // optional filter name selecting the image grade: 'lose' | 'alien' | 'cult'
  @:optional var filter: String;
}
