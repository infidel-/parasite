package render.facility;

// one field of blinking status lights, as render.facility.FacilityDeco.lights takes it.
//
// REPLACED the 10-positional `lights(b, x0, x1, z0, z1, y, h, dir, col, row)` when the corp tower
// asked for the same field over ITS rack art: the band the specks sit in, how many of them and how
// big they are were FacilityStyle constants fitted to the compound's own image, and a second image
// with three cabinets across instead of six cannot be spelled by any of the ten arguments.
typedef LedOpts = {
  // the fitting's box in world, and the face the field lies a hair proud of
  var x0:Float;
  var x1:Float;
  var z0:Float;
  var z1:Float;
  // the face's foot and its height
  var y:Float;
  var h:Float;
  // which hand the face looks down — FacilityGeom.ends' numbering (0 -z, 1 +z, 2 -x, 3 +x)
  var dir:Int;
  // the cell, which seeds every speck's level, phase and hue
  var col:Int;
  var row:Int;
  // the band across the FACE the specks sit in, as a fraction of its width — read off the art, and
  // measured from the texture's own u origin (see `lights`, which is where that trap is written up)
  var u0:Float;
  var u1:Float;
  // how many rows of specks up the face, and how many across the band
  var rows:Int;
  var cols:Int;
  // one speck's world size
  var size:Float;
}
