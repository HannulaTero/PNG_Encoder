/// @desc CLEANUP.


if (surface_exists(surface) == true)
{
  surface_free(surface);
}


buffer_delete(buffer);