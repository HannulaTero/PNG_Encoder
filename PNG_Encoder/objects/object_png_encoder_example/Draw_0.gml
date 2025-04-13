/// @desc HUD.

draw_text(64, 64, "Press SPACE to create random image.");
draw_text(64, 80, "Press ENTER to create and save PNG file.");


if (surface_exists(surface) == true)
{
  var _w = 640;
  var _h = _w * size[1] / size[0];
  draw_surface_stretched(surface, 64, 128, _w, _h);
}