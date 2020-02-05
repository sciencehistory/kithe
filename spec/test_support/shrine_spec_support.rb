module ShrineSpecSupport
  # copied from
  # https://github.com/shrinerb/shrine/blob/203c2c9a0c83815c9ded1b09d5d006b2a523579c/test/support/generic_helper.rb#L6
  def test_uploader(storage_key = :store, &block)
    uploader_class = Class.new(Shrine)
    uploader_class.plugin :model
    uploader_class.storages[:cache] = Shrine::Storage::Test.new
    uploader_class.storages[:store] = Shrine::Storage::Test.new
    uploader_class.class_eval(&block) if block
    uploader_class.new(storage_key)
  end

  def test_attacher!(*args, attachment_options: {}, &block)
    uploader = test_uploader(*args, &block)
    Object.send(:remove_const, "TestUser") if defined?(TestUser) # for warnings
    user_class = Object.const_set("TestUser", Struct.new(:avatar_data, :id))
    user_class.include uploader.class::Attachment(:avatar, **attachment_options)
    user_class.new.avatar_attacher
  end

  # https://github.com/shrinerb/shrine/blob/203c2c9a0c83815c9ded1b09d5d006b2a523579c/test/support/generic_helper.rb#L27
  def fakeio(content = "file", **options)
    FakeIO.new(content, **options)
  end
end


class Shrine
  def warn(*); end # disable mime_type warnings
end

require 'shrine/storage/memory'

# https://github.com/shrinerb/shrine/blob/203c2c9a0c83815c9ded1b09d5d006b2a523579c/test/support/test_storage.rb
class Shrine
  module Storage
    class Test < Memory
      def download(id)
        tempfile = Tempfile.new(["shrine", File.extname(id)], binmode: true)
        IO.copy_stream(open(id), tempfile)
        tempfile.tap(&:open)
      end

      def move(io, id, **options)
        store[id] = io.storage.delete(io.id)
      end

      def movable?(io, id)
        io.is_a?(UploadedFile) && io.storage.is_a?(Storage::Memory)
      end
    end
  end
end


# https://github.com/shrinerb/shrine/blob/203c2c9a0c83815c9ded1b09d5d006b2a523579c/test/support/fakeio.rb
require "forwardable"
require "stringio"
class FakeIO
  attr_reader :original_filename, :content_type

  def initialize(content, filename: nil, content_type: nil)
    @io = StringIO.new(content)
    @original_filename = filename
    @content_type = content_type
  end

  extend Forwardable
  delegate %i[read rewind eof? close size] => :@io
end
