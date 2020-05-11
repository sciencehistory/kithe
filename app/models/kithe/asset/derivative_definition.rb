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

  def call(original_file:,attacher:)
    if proc_accepts_keyword?(:attacher)
      proc.call(original_file, attacher: attacher)
    else
      proc.call(original_file)
    end
  end

  # Do content-type restrictions defined for this definition match a given asset?
  def applies_to_content_type?(original_content_type)
    return true if content_type.nil?

    return true if content_type == original_content_type

    return false if original_content_type.nil?

    return true if (content_type.kind_of?(Array) && content_type.include?(original_content_type))

    content_type == original_content_type.sub(%r{/.+\Z}, '')
  end

  private

  def proc_accepts_keyword?(kwarg)
    proc.parameters.include?([:key, kwarg]) || proc.parameters.include?([:keyreq, kwarg]) || proc.parameters.find {|a| a.first == :keyrest}
  end
end
