/// @desc CREATE RANDOM IMAGE.
// feather ignore GM1017


if (keyboard_check_pressed(vk_space) == false)
{
  exit;
}


// Preparations.
var _w = get_integer("Give me width", 640);
var _h = get_integer("Give me height", 480);
var _count = _w * _h;
var _bytes = _count * 4;
size[0] = _w;
size[1] = _h;


// Resize the structures.
buffer_resize(buffer, _bytes);

if (surface_exists(surface) == true)
{
  surface_resize(surface, _w, _h);
}
else
{
  surface = surface_create(_w, _h);
}


// Create the random image for example.
surface_set_target(surface);
draw_clear_alpha(0, 0);
repeat(64)
{
  var _x = random(_w);
  var _y = random(_h);
  var _r = min(_w, _h) * 0.25;
  var _outline = choose(true, false);
  var _col1 = make_color_hsv(irandom(255), 192, 256);
  var _col2 = make_color_hsv(irandom(255), 192, 256);
  draw_circle_color(_x, _y, _r, _col1, _col2, _outline);
}
surface_reset_target()


// Get the raw image data into buffer.
buffer_get_surface(buffer, surface, 0);



