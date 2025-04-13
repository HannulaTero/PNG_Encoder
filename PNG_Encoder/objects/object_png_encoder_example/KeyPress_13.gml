/// @desc CREATE & SAVE THE PNG FILE.


// Encode raw image into PNG.
var _png = png_encode(buffer, size[0], size[1], {
  colors: "rgba", 
  chunk:  256*256,
  bits:   8, 
  texts: {
    Title: "Test Image",
    Author: "Tero Hannula",
    Description: "This is test image for PNG creation.",
    Comment: "Generated in GameMaker"
  },
});


// Save the image.
var _path = get_save_filename("png|*.png", "test image");
if (_path == "") 
{
  show_debug_message("Saving was cancelled.");
} 
else 
{
  buffer_save(_png, _path);
}


// Clean up the image.
buffer_delete(_png);