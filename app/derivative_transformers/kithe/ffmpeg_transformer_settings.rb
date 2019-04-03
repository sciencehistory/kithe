module Kithe
  # Example settings to pass to ffmpeg_transformer.

  class FfmpegTransformerSettings
    SETTINGS = {
      :mono_webm => {
        label: :mono_webm,
        suffix: 'webm',
        content_type: 'audio/webm',
        conversion_settings: [
          # Mix stereo down to mono:
          "-ac", "1",
          # Use the libopus codec to convert the audio to webm:
          "-codec:a", "libopus",
          # Output audio should have 64k samples per second.
          "-b:a", "64k"]
      },
      :stereo_webm => {
        label: :stereo_webm,
        suffix: 'webm',
        content_type: 'audio/webm',
        conversion_settings: [
          # Use the libopus codec to convert the audio to webm:
          "-codec:a", "libopus",
          # Output audio should have 64k samples per second.
          "-b:a", "64k"]
      },
      :mono_mp3 => {
        label:  :mono_mp3,
        suffix: 'mp3',
        content_type: 'audio/mpeg',
        conversion_settings: [
          # Mix stereo down to mono:
          "-ac", "1",
          # Output audio should have 64k samples per second.
          "-b:a", "64k"
        ]
      },
      :stereo_mp3 => {
        label:  :stereo_mp3,
        suffix: 'mp3',
        content_type: 'audio/mpeg',
        conversion_settings: [
          # Output audio should have 64k samples per second.
          "-b:a", "64k"
        ]
      }
    }
  end
end