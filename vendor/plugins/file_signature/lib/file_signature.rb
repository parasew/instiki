# -*- coding: utf-8 -*-
=begin rdoc
Please see README
=end

class IO

  # We implement magic by using a lookup hash.
  # The key is a string that encodes the first bits.
  # The value is a symbol that indicates the magic type.
  #
  # Examples:
  #   IO::MagicNumberType("BM") => :bitmap
  #   IO::MagicNumberType("GIF8") => :gif
  #   IO::MagicNumberType("\xa6\x00") => :pgp_encrypted_data
  #
  # Quirks:
  #   - JPEG adjustment:
  #     - Some cameras put JPEG Exif data in bytes 3 & 4,
  #       so we only check the first two bytes of a JPEG.
  #   - TIFF has two possible matches:
  #     - MM** is Motorola big endian
  #     - II** is Intel little ending
  #
  # See:
  #  - IO#magic_number_type
  #  - File.magic_number_type

  SignatureMap = {
    "BC" => :bitcode,
    [0xDE,0xC0,0x17,0x0B].pack('c*') => :bitcode,
    "BM" => :bitmap,
    "BZ" => :bzip,
    "MZ" => :exe,
    "SIMPLE"=> :fits,
    "GIF87a" => :gif,
    "GIF89a" => :gif,
    "GKSM" => :gks,
    [0x01,0xDA].pack('c*') => :iris_rgb,
    [0xF1,0x00,0x40,0xBB].pack('c*') => :itc,
    [0xFF,0xD8,0xFF].pack('c*') => :jpeg,
    "IIN1" => :niff,
    "MThd" => :midi,
    "%PDF" => :pdf,
    "VIEW" => :pm,
    [0x89].pack('c*') + "PNG" + [0x0D,0x0A,0x1A,0x0A].pack('c*') => :png,
    "%!PS-Adobe-" => :postscript,
    "Y" + [0xA6].pack('c*') + "j" + [0x95].pack('c*') => :sun_rasterfile,
    "MM*" + [0x00].pack('c*') => :tiff,
    "II*" + [0x00].pack('c*') => :tiff,
    "gimp xcf" => :gimp_xcf,
    "#FIG" => :xfig,
    "/* XPM */" => :xpm,
    [0x23,0x21].pack('c*') => :shebang,
    [0x1F,0x9D].pack('c*') => :compress,
    [0x1F,0x8B,0x08].pack('c*') => :gzip,
    "PK" + [0x03,0x04].pack('c*') => :pkzip,
    "Rar" + [0x20,0x1A,0x07,0x00].pack('c*') => :rar,
    [0x1A,0x45,0xDF,0xA3].pack('c*') => :webm,
    [0x4F,0x67,0x67,0x53,0x00].pack('c*') => :ogg,
    "fLaC" + [0x00,0x00,0x00,0x22].pack('c*') => :flac,
    [0x00,0x00,0x01,0x00].pack('c*') => :ico,
    [0x49,0x44,0x33].pack('c*') => :mp3,
    "#EXTM3U" => :m3u8,
    ".ELF" => :unix_elf,
    [0x99,0x00].pack('c*') => :pgp_public_ring,
    [0x95,0x01].pack('c*') => :pgp_security_ring,
    [0x95,0x00].pack('c*') => :pgp_security_ring,
    [0xA6,0x00].pack('c*') => :pgp_encrypted_data,
    [0xD0,0xCF,0x11,0xE0].pack('c*') => :docfile
  }

  MimeTypeMap = {
    :compress => 'application/x-compress',
    :gzip => 'application/x-gzip',
    :pkzip => 'application/zip',
    :rar => 'application/x-rar-compressed',
    :webm => 'video/webm',
    :ogg => 'application/ogg',
    :ico => 'image/vnd.microsoft.icon',
    :mp3 => 'audio/mpeg',
    :mp4 => 'video/mp4',
    :video_3gpp => 'video/3gpp',
    :video_3gpp2 => 'video/3gpp2',
    :quicktime => 'video/quicktime',
    :m4v => 'video/x-m4v',
    :m4a => 'audio/mp4a-latm',
    :aiff => 'audio/x-aiff',
    :flac => 'audio/flac',
    :niff => 'application/vnd.music-niff',
    :midi => 'audio/midi',
    :fits => 'image/fits',
    :gimp_xcf => 'image/xcf',
    :unix_elf => 'application/octet-stream',
    :bitcode => 'application/octet-stream',
    :gks => 'application/octet-stream',
    :iris_rgb => 'application/octet-stream',
    :itc => 'application/octet-stream',
    :pm => 'application/octet-stream',
    :pgp_public_ring => 'application/octet-stream',
    :pgp_security_ring => 'application/octet-stream',
    :pgp_encrypted_data => 'application/octet-stream',
    :pgp_public_ring => 'application/octet-stream',
    :pgp_public_ring => 'application/octet-stream',
    :docfile => 'application/msword',
    :xfig => 'application/x-fig',
    :xpm => 'image/x-xpixmap',
    :shebang => 'text/plain',
    :bitmap => 'image/bmp',
    :png => 'image/png',
    :gif => 'image/gif',
    :jpeg => 'image/jpeg',
    :sun_rasterfile => 'image/x-cmu-raster',
    :postscript => 'application/postscript',
    :pdf => 'application/pdf',
    :tiff => 'image/tiff',
    :bzip => 'application/x-bzip',
    :exe => 'application/x-msdownload',
    :wave => 'audio/wave',
    :webp => 'image/webp',
    :m3u8 => 'application/vnd.apple.mpegURL'
  }

  SignatureSize = [14, SignatureMap.keys.inject(0){ |m,k| k.length > m ? k.length : m }].max


  # Detect the data type by checking various "magic number" conventions
  # for the introductory bytes of a data stream
  #
  # Return the "magic number" as a symbol:
  #  - :bitmap = Bitmap image file, typical extension ".bmp"
  #  - :gzip = Unix GZIP compressed data, typical extension ".gz"
  #  - :postscript = Postscript pages, typical extension ".ps"
  #
  # Return nil if there's no match for any known magic number.
  #
  # Example:
  #   f = File.open("test.ps","rb")
  #   put f.magic_number(s)
  #   => :postscript
  #
  # See:
  #  - IO::MagicNumberTypeHash
  #  - File.magic_number_type

  def magic_number_type
    return @magic_number_memo if defined? @magic_number_memo

    bytes = ""
    type = nil

    while bytes.size < SignatureSize
      bytes += read(1)
      type = SignatureMap[bytes]
      break if type
    end

    #some cases require a more complicated match
    type = :aiff if (bytes[0,4] == 'FORM' && bytes[8,3] == 'AIF')
    type = :quicktime if bytes[4,4] == 'moov'
    if bytes[0,4] == 'RIFF'
      case bytes[8,6]
      when "WAVEfm"
        type = :wave
      when "WEBPVP"
        type = :webp
      end
    end
    if bytes[4,4] == 'ftyp'
      case bytes[8,3]
      when 'iso', 'mp4', 'avc'
        type = :mp4
      when '3ge', '3gg', '3gp'
        type = :video_3gpp
      when '3g2'
        type = :video_3gpp2
      when 'M4A'
        type = :m4a
      when 'M4V'
        type = :m4v
      when 'qt '
        type = :quicktime
      end
    end

    @magic_number_memo = type
  end

  # Return the MIME type of the IO stream
  # It's obtained by first finding the magic_number,
  # and then looking up the MIME type from a hash.
  # Returns 'application/octet-stream' for unknown types 
  def mime_type
    return @mime_memo if defined? @mime_memo
    type = self.magic_number_type
    if type
      m = MimeTypeMap[type]
    else
      m = 'application/octet-stream'
    end
    @mime_memo = m
  end

end


class File

  # Detect the file's data type by opening the file then
  # using IO#magic_number_type to read the first few bytes.
  #
  # Return a magic number type symbol, e.g. :bitmap, :jpg, etc.
  #
  # Example:
  #   puts File.magic_number_type("test.ps") => :postscript
  #
  # See
  #   - IO#MagicNumberTypeHash
  #   - IO#magic_number_type

  def self.magic_number_type(file_name)
    File.open(file_name,"rb"){|f| f.magic_number_type }
  end
  
  # Same, but return the MIME type of the file.
  # Returns 'application/octet-stream' for unknown types.
  def self.mime_type(file_name)
    File.open(file_name,"rb"){|f| f.mime_type }
  end

end

