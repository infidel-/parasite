package lighting;

import js.html.Image;

// one dynamic actor sprite prepared for projected-shadow masking
typedef _AIShadowCaster = {
  var caster: _ProjectedShadowCaster;
  var layer: Image;
  var maskKey: String;
}
