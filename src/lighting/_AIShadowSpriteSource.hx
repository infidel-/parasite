package lighting;

import js.html.Image;

// one sprite-atlas source reference for dynamic actor shadows
typedef _AIShadowSpriteSource = {
  var imageKey: String;
  var image: Image;
  var srcRow: Int;
  var srcCol: Int;
}
