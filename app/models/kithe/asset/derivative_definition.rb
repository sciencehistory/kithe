# A definition of a derivative creation routine, this is intended to be an internal
# class, it's what's created when you call Kithe::Asset#define_derivative
class Kithe::Asset::DerivativeDefinition
  attr_reader :key, :content_type, :default_create, :proc, :storage_key
  def initialize(key:, proc:, content_type: nil, default_create: true)
    @key = key.to_sym
    @content_type = content_type
    @default_create = default_create
    @proc = proc
  end

  # @return [Hash] add_metadata hash of metadata to add to derivative on storage
  def call(original_file:,attacher:)
    add_metadata = {}
    kwargs = {}

    if proc_accepts_keyword?(:attacher)
      kwargs[:attacher] = attacher
    end

    if proc_accepts_keyword?(:add_metadata)
      kwargs[:add_metadata] = add_metadata
    end

    return_val = if kwargs.present?
      proc.call(original_file, **kwargs)
    else
      proc.call(original_file)
    end

    # Save in context to later write to actual stored derivative metadata
    if add_metadata.present?
      attacher.context[:add_metadata] ||= {}
      attacher.context[:add_metadata][key] = add_metadata
    end

    return_val
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
