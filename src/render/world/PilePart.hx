package render.world;

// one kind of piece a street pile deals from (render.world.Pile, StreetProps.deal)
typedef PilePart = {
  path:String,           // the glb (RenderConfig.MODELS)
  h:Float,               // world height it is drawn at in this pile, before the pile's size jitter
  r:Float,               // world radius of its footprint: how close the next piece may stand
  weight:Float,          // odds it is dealt against the pile's other parts
  ?back:Bool,            // HEAP: stands at the wall's foot (a flattened carton leant on it); give it a `turn`
  ?front:Bool,           // HEAP: spilt toward the street ahead of the rest (a sack lying on its side)
  ?turn:Float,           // radians of yaw either way off square to the street; absent = turned any way
  ?at:Array<Float>,      // LOAD: [x, y, z] the one place it stands, prop-local world units (the board
                         // out of the cart's nose); absent = dealt over the bed
};
