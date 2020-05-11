# A definition of a derivative creation routine, this is intended to be an internal
# class, it's what's created when you call Kithe::Asset#define_derivative
class Kithe::Asset::DerivativeDefinition
  attr_reader :key, :content_type, :default_create, :proc, :storage_key
  def initialize(key:, proc:, content_type: nil, default_create: true)
    @key = key
    @content_type = content_type
    @default_create = default_create
    @proc = proc
  end

  def call(original_file:,record:)
    if proc_accepts_record_keyword?
      proc.call(original_file, record: record)
    else
      proc.call(original_file)
    end
  end

  # Do content-type restrictions defined for this definition match a given asset?
  def applies_to?(asset)
    return true if content_type.nil?

    return true if content_type == asset.content_type

    return false if asset.content_type.nil?

    return true if (content_type.kind_of?(Array) && content_type.include?(asset.content_type))

    content_type == asset.content_type.sub(%r{/.+\Z}, '')
  end

  private

  def proc_accepts_record_keyword?
    proc.parameters.include?([:key, :record]) || proc.parameters.include?([:keyreq, :record]) || proc.parameters.find {|a| a.first == :keyrest}
  end
end
