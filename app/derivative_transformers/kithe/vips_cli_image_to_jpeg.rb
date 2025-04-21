require 'tempfile'
require 'tty/command'

module Kithe
  # Use the [vips](https://jcupitt.github.io/libvips/) command-line utility (via shell-out)
  # to transform any image type to a JPG, with a specified maximum width (keeping aspect ratio).
  #
  # Requires vips command line utilities `vips` and `vipsthumbnail` and to be installed on your system,
  # eg `brew install vips`, or apt package `vips-tools`.
  #
  # If thumbnail_mode:true is given, we ALSO apply some additional best practices
  # for minimizing size when used as an image _in a browser_, such as removing
  # color profile information. See eg:
  #  * https://developers.google.com/speed/docs/insights/OptimizeImages
  #  * http://libvips.blogspot.com/2013/11/tips-and-tricks-for-vipsthumbnail.html
  #  * https://github.com/jcupitt/libvips/issues/775
  #
  # It takes an open `File` object in, and returns an open TempFile object. It is
  # built for use with kithe derivatives transformations, eg:
  #
  #     class Asset < KitheAsset
  #       define_derivative(thumb) do |original_file|
  #         Kithe::VipsCliImageToJpeg.new(max_width: 100, thumbnail_mode: true).call(original_file)
  #       end
  #     end
  #
  # We use the vips CLI because we know how, and it means we can avoid worrying
  # about ruby memory leaks or the GIL. An alternative that uses vips ruby bindings
  # would also be possible, and might work well, but this is what for us is tried
  # and true.
  #
  # Some usage suggestions at https://www.libvips.org/API/current/Using-vipsthumbnail.html
  class VipsCliImageToJpeg
    class_attribute :srgb_profile_path, default: Kithe::Engine.root.join("lib", "vendor", "icc", "sRGB2014.icc").to_s
    class_attribute :vips_thumbnail_command, default: "vipsthumbnail"
    class_attribute :vips_command, default: "vips"

    attr_reader :max_width, :jpeg_q

    def initialize(max_width:nil, jpeg_q: 85, thumbnail_mode: false)
      @max_width = max_width
      @jpeg_q = jpeg_q
      @thumbnail_mode = !!thumbnail_mode

      if thumbnail_mode && max_width.nil?
        # https://github.com/libvips/libvips/issues/1179
        raise ArgumentError.new("thumbnail_mode currently requires a non-nil max_width")
      end
    end

    # Will raise TTY::Command::ExitError if the external Vips command returns non-null.
    def call(original_file)
      tempfile = Tempfile.new(["kithe_vips_cli_image_to_jpeg", ".jpg"])

      vips_args = []

      # If we are resizing, we use `vipsthumbnail`, if we are not resizing,
      # `vips copy` works better.
      if max_width
        # Due to bug in vips, we need to provide a height constraint, we make
        # really huge one million pixels so it should not come into play, and
        # we're constraining proportionally by width.
        # https://github.com/jcupitt/libvips/issues/781
        vips_args.concat [vips_thumbnail_command, original_file.path]
        vips_args.concat maybe_profile_normalization_args
        vips_args.concat ["--size", "#{max_width}x65500"]
        vips_args.concat ["-o", "#{tempfile.path}#{vips_jpg_params}"]
      else
        # If we arne't making a thumbnail, we need to use `vips copy` instead of `vipsthumbnail`,
        # to avoid it changing height/width on us. There might be another way.
        #
        # Yes, this means we can't do thumbnail-mode normalizations.
        vips_args.concat [vips_command, "copy", original_file.path]
        vips_args.concat ["#{tempfile.path}#{vips_jpg_params}"]
      end

      TTY::Command.new(printer: :null).run(*vips_args)

      return tempfile
    end

    private

    def thumbnail_mode?
      @thumbnail_mode
    end

    # Only if we're in thumbnail_mode mode, normalize to rRGB profile, and then strip
    # embedded profile info for a smaller size, since browsers assume sRGB
    def maybe_profile_normalization_args
      return [] unless thumbnail_mode?

      ["--export-profile", srgb_profile_path, "--delete"]
    end

    # Params to add on to end of JPG output path, as in:
    # `vips convert ... -o something.jpg[Q=85]`
    #
    # If we are in thumbnail mode, we strip all profile information for
    # smaller files.
    #
    # Either way we create an interlaced JPG and optimize coding for smaller
    # file size.
    #
    # @returns [String]
    def vips_jpg_params
      if thumbnail_mode?
        "[Q=#{jpeg_q},interlace,optimize_coding,keep=none]"
      else
        # could be higher Q for downloads if we want, but we don't right now
        # We do avoid striping metadata, no 'strip' directive.
        "[Q=#{jpeg_q},interlace,optimize_coding]"
      end
    end
  end
end
