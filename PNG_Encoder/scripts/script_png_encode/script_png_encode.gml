//=============================================================
// 
#region LICENSE.
/*

  MIT License

  Copyright (c) 2025 Tero Hannula

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.


*/
#endregion
//
//=============================================================
// 
#region PNG ENCODER.
/*
  
  This script is used to generate PNG images from raw buffer data.
  It will return buffer, which can be saved with buffer_save,
  and that "should" now work as png -file.
  
  Not everything is tested, and things might not work.
  - Most likely the bit-depths smaller than 8 will cause issues.
  - Bit depth 16 might work, haven't tested.
  - Also I have not tested the palette.
  Basically, I have only tested regular RGBA 8bit images.
  
  
  As user you only need to care about the encoder function.
  You should not need to touch the helper functions.
  
*/
#endregion
//
//=============================================================
// 
#region PNG ENCODER.


/**
* Creates new buffer, which contains source image as encoded png-file. 
* @param {Id.Buffer}  _src    Unformatted image pixel data
* @param {Real}       _w      Image width
* @param {Real}       _h      Image height
* @param {Struct}     _params Other parameters, check "defaultParam" -struct.
*/
function png_encode(_src, _w, _h, _params={}) 
{
  //=============================================================
  // 
  #region INITIALIZE STATIC VARIABLES.
  
  
  // SUPPORTED COLOR TYPES and THEIR BIT DEPTHS
  // These are from png specifications.
  static supportedColortypes = {
  	r:      0,  // Gray
  	rg:     4,  // Gray + alpha
  	rgb:    2,  // Truecolor
  	rgba:   6,  // Truecolor + alpha
  	index:  3	  // Indexed palette color
  }
  
  static supportedBitdepth = {
  	r:      [ 1, 2, 4, 8, 16 ], // Gray
  	rg:     [ 8, 16 ],          // Gray + alpha
  	rgb:    [ 8, 16 ],          // Truecolor
  	rgba:   [ 8, 16 ],          // Truecolor + alpha
  	index:  [ 1, 2, 4, 8 ]      // Palette color
  }
  
  static channelCount = {
    r:      1,  // Gray
    rg:     2,  // Gray + alpha
    rgb:    3,  // Truecolor
    rgba:   4,  // Truecolor + alpha
    index:  1	  // Palette color
  }
  
  
  // DEFAULT PARAMETERS
  // Tell what kind of data is being encode
  // Also extra information such as data chunk size and texts
  static defaultParam = {
    colors:   "rgba",     // Check supportedColortypes
    bits:     8,          // 8bit, check supportedBitDepth
    chunk:    1 << 16,    // 65kb, how large data-chunks can be.
    palette:  undefined,  // If uses indexes palette color type
    texts:    { }         // Each struct-key is keyword, and content should be string
  }
  
  
  #endregion
  //
  //=============================================================
  // 
  #region READ THE PARAMETERS.
  
  
  // GET PARAMETERS
  var _colortypeName  = _params[$ "colors"]   ?? defaultParam.colors;
  var _bitdepth       = _params[$ "bits"]     ?? defaultParam.bits;
  var _dataChunkSize  = _params[$ "chunk"]    ?? defaultParam.chunk;
  var _palette        = _params[$ "palette"]  ?? defaultParam.palette;
  var _texts          = _params[$ "texts"]    ?? defaultParam.texts;
  
  
  // CHECK SIZE
  if (_w < 1) || (_w > 16384)
  if (_h < 1) || (_h > 16384) 
  {
    throw($"Size must be in range of 1 to 16384, got: [{_w}][{_h}]");
  }
  
  
  // COLOR TYPE
  // Check whether supported color type
  var _colortype = supportedColortypes[$ _colortypeName];
  if (is_undefined(_colortype)) 
  {
    throw($"Unknown png color type: {_colortypeName}");
  }
  var _channels = channelCount[$ _colortypeName];
  
  
  // COLOR BIT DEPTH
  // Check whether supported bitdepth at given color type
  var _found = false;
  var _bitlist = supportedBitdepth[$ _colortypeName];
  for(var i = 0; i < array_length(_bitlist); i++) 
  {
    if (_bitlist[i] == _bitdepth) 
    {
      _found = true;
      break;
    }
  }
  
  if (_found == false) 
  {
  	throw($"Unsupported bitdepth {_bitdepth} for color type {_colortypeName}");
  }
  
  
  #endregion
  //
  //=============================================================
  // 
  #region ADD THE PNG HEADER & METADATA.
  
  
  // RESULT BUFFER - Create return buffer
  var _dest = buffer_create(256, buffer_grow, 1);
  
  
  // PNG FILE HEADER
  // Signature, tells that this is a png file. 
  png_add_bytes(_dest, 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A);
  
  
  // PNG IHDR CHUNK
  // Information about pixels
  // Used here: Compression method 0, filter method 0, interlace 0
  png_add_bigendian(_dest, 13); // IHDR has always length of 13
  var _posIHDR = buffer_tell(_dest); 
  png_add_text(_dest, "IHDR");
  png_add_bigendian(_dest, _w);
  png_add_bigendian(_dest, _h);
  png_add_bytes(_dest,  
    _bitdepth,  // Bit depth
    _colortype, // Colour type
    0,  // Compression method
    0,  // Filter method
    0   // Interlace method
  );
  png_add_crc(_dest, _posIHDR);
  
  
  #endregion
  //
  //=============================================================
  // 
  #region ADD TEXT CHUNKS.
  
  
  // Write textual data, Each keyword and it's text are on their own chunk.
  // Keyword is uncompressed, but in this implementation text is always being compressed.
  var _keywords = variable_struct_get_names(_texts);
  var _keywordCount = array_length(_keywords);
  for(var i = 0; i < _keywordCount; i++) 
  {
    // Keyword sanity check
    var _keyword = _keywords[i];
    var _keywordSize = string_byte_length(_keyword);
    if (_keywordSize > 79) 
    {
      throw($"Text keyword cannot exceed 79 bytes, keyword '{_keyword}' has {_keywordSize} bytes");
    }
    
    
    // Compress text
    var _text		= _texts[$ _keyword];
    var _textSize	= string_byte_length(_text);
    var _textBuff	= buffer_create(_textSize, buffer_fixed, 1);
    buffer_write(_textBuff, buffer_text, _text);
    var _textCompressed = buffer_compress(_textBuff, 0, _textSize);
    buffer_delete(_textBuff);
    _textSize = buffer_get_size(_textCompressed);
    
    
    // Resize result buffer to accomodate text chunk
    var _chunkSize = _keywordSize + _textSize + 2;
    var _oldSize = buffer_tell(_dest);
    var _newSize = _oldSize + _chunkSize + 12;
    buffer_resize(_dest, _newSize);
    
    
    // Create text chunk
    png_add_bigendian(_dest, _chunkSize);
    var _poszTXt = buffer_tell(_dest); 
    png_add_text(_dest, "zTXt");
    png_add_text(_dest, _keyword);
    png_add_bytes(_dest, 0x00, 0x00); // null separator, compression method
    buffer_copy(_textCompressed, 0, _textSize, _dest, buffer_tell(_dest));
    buffer_seek(_dest, buffer_seek_relative, _textSize);
    png_add_crc(_dest, _poszTXt);
    buffer_delete(_textCompressed);
  }
  
  
  #endregion
  //
  //=============================================================
  // 
  #region ADD PALETTE CHUNK.
  
  
  // If using palette color type, then associated palette table must be included
  // This is only necessary with palette color type, others don't need it
  // Palette contains 1 to 256 palette entries, each a three bytes representing RGB
  // Number of entries is determined from chunk length, so chunk not divisible by 3 is error.
  if (is_undefined(_palette) == false) 
  {
    // Sanity checks
    var _paletteSize = buffer_get_size(_palette);
    var _paletteCount = _paletteSize / 3;
    if ((_paletteSize mod 3) != 0) 
    {
    	throw("Palette must be divisable by 3.");
    }
    
    if (_paletteCount < 1)
    || (_paletteCount > power(2, _bitdepth)) 
    {
    	throw($"Palette with bitdepth {_bitdepth} can only have 1 to {power(2, _bitdepth)} entries, got {_paletteCount}.");
    }
    
    if (_colortype != supportedColortypes.index)
    || (_colortype != supportedColortypes.rgb) // palette for rgb and rgba is optional.
    || (_colortype != supportedColortypes.rgba) 
    {
    	throw("Palette cannot be used with grayscale image.");
    }
    
    
    // Resize target buffer to accommodate palette
    var _oldSize = buffer_tell(_dest);
    var _newSize = _oldSize + _paletteSize + 12;
    buffer_resize(_dest, _newSize);
    
    
    // Create palette chunk
    png_add_bigendian(_dest, _paletteSize);
    var _posPLTE = buffer_tell(_dest);
    png_add_text(_dest, "PLTE");
    buffer_copy(_palette, 0, _paletteSize, _dest, buffer_tell(_dest));
    buffer_seek(_dest, buffer_seek_relative, _paletteSize);
    png_add_crc(_dest, _posPLTE);
  }
  
  
  #endregion
  //
  //=============================================================
  // 
  #region ADD COMPRESSED SCAN-LINES.
  
  
  // Data consists of horizontal scanlines. 
  // In GML, we are always going to use zlib compression
  // Each scanline starts with byte, which tells filtering method
  // As filtering is not being used, its value is 0.
  // So before compression, we have to add these bytes
  var _srcSize        = buffer_get_size(_src);
  var _scanlinesSize  = _srcSize + _h; // Additional scanline filter bytes.
  var _scanlines      = buffer_create(_scanlinesSize, buffer_fixed, 1);
  var _rowBytes       = _w * _channels * _bitdepth / 8;
  for(var i = 0; i < _srcSize; i += _rowBytes) 
  {
    buffer_write(_scanlines, buffer_u8, 0); // Filter method
    buffer_copy(_src, i, _rowBytes, _scanlines, buffer_tell(_scanlines));
    buffer_seek(_scanlines, buffer_seek_relative, _rowBytes);
  }
  var _data		= buffer_compress(_scanlines, 0, _scanlinesSize);
  var _dataSize	= buffer_get_size(_data);
  buffer_delete(_scanlines);
  
  
  // Resize to be able to be able to copy over IDAT chunks
  var _oldSize = buffer_tell(_dest);
  var _newSize = _oldSize + _dataSize + 12 * ceil(_dataSize / _dataChunkSize);
  buffer_resize(_dest, _newSize);
  
  
  // PNG IDAT CHUNK 
  // Add parts of compressed pixel data into each chunk.
  for(var i = 0; i < _dataSize; i += min(_dataChunkSize, _dataSize-i)) 
  {
    var _stepSize = min(_dataChunkSize, _dataSize-i);
    png_add_bigendian(_dest, _stepSize);
    var _posIDAT = buffer_tell(_dest);
    png_add_text(_dest, "IDAT");
    buffer_copy(_data, i, _stepSize, _dest, buffer_tell(_dest));
    buffer_seek(_dest, buffer_seek_relative, _stepSize);
    png_add_crc(_dest, _posIDAT);
  }
  buffer_delete(_data);
  
  
  #endregion
  //
  //=============================================================
  // 
  #region FINALIZE - ADD PNG IEND CHUNK.
  
  
  // This will tell that file ends, and adds check-sum.
  png_add_bigendian(_dest, 0); 
  var _posIEND = buffer_tell(_dest);
  png_add_text(_dest, "IEND");
  png_add_crc(_dest, _posIEND);
  
  
  #endregion
  //
  //=============================================================
  // 
  #region RETURN THE RESULT.
    
  
  buffer_resize(_dest, buffer_tell(_dest));
  buffer_seek(_dest, buffer_seek_start, 0);
  return _dest;
  
  
  #endregion
  //
  //=============================================================
}



#endregion
//
//=============================================================
// 
#region PNG ENCODER - HELPER FUNCTIONS.



/**
* Adds chunk name 
* @param {Id.Buffer}  _buff
* @param {String}     _name
*/
function png_add_text(_buff, _name) 
{
  buffer_write(_buff, buffer_text, _name);
}


/**
* Add multiple separate bytes at once [8bit values].
* @param {Id.Buffer} _buff
*/
function png_add_bytes(_buff) {
  for(var i = 1; i < argument_count; i++) 
  {
    buffer_write(_buff, buffer_u8, argument[i]);
  }
}


/**
* Adds compressed data to the end.
* @param {Id.Buffer} _file
* @param {Id.Buffer} _data
* @param {Real} _dataPos
* @param {Real} _dataSize
*/
function png_add_data(_file, _data, _dataPos=0, _dataSize=buffer_get_size(_data)) 
{
  var _fileTell = buffer_tell(_file);
  buffer_resize(_file, _fileTell + _dataSize);
  buffer_copy(_data, _dataPos, _dataSize, _file, _fileTell);
  buffer_seek(_file, buffer_seek_end, 0);
}


/**
* GML uses little-endian, so transoform u32 value to big-endian
* @param {Id.Buffer}  _buff
* @param {Real}       _value
*/
function png_add_bigendian(_buff, _value) 
{
  // Validity check.
	if (is_numeric(_value) == false)
  || (_value < 0) 
  || (_value >= (1 << 32)) 
  {
    throw($"Invalid input value for png_add_bigendian: {_value}");
  }
  
  // Reverse the byte order.
	buffer_write(_buff, buffer_u8, (_value & 0xff000000) >> 24);
	buffer_write(_buff, buffer_u8, (_value & 0xff0000) >> 16);
	buffer_write(_buff, buffer_u8, (_value & 0xff00) >> 8);
	buffer_write(_buff, buffer_u8, (_value & 0xff));
}


/**
* Adds crc 32bit checksum hash at end. Xor must be used.
* @param {Id.Buffer}  _buff
* @param {Real}       _pos
*/
function png_add_crc(_buff, _pos) 
{
  var _size = buffer_tell(_buff) - _pos;
  var _crc = buffer_crc32(_buff, _pos, _size);
  png_add_bigendian(_buff, _crc ^ 0xFFFFFFFF);
}


#endregion
//
//=============================================================








