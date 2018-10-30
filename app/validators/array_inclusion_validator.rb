# Like the default Rails inclusion validator, but the built-in Rails
# validator won't work on an _array_ of things.
#
# So if you have an array of primitive values, you can use this to
# validate that all elements of the array are in the inclusion list.
#
# Emtpy arrays are always allowed, add a presence validator if you don't
# want to allow them, eg `validates :genre, presence: true, array_inclusion: { in: whatever }`
#
# @example
#    class Work < Kithe::Work
#      attr_json :genre, :string, array: true
#      validates :genre, array_inclusion: { in: ALLOWED_GENRES  }
#      #...
#
# Custom message can interpolate `rejected_values` value. (Should also work for i18n)
#
# @example
#     validates :genre, array_inclusion: { in: ALLOWED_GENRES, message: "option %{rejected_values} not allowed"  }
class ArrayInclusionValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    not_allowed_values = (value || []) - options[:in]
    unless not_allowed_values.blank?
      formatted_rejected = not_allowed_values.uniq.collect(&:inspect).join(",")
      record.errors.add(attribute, :inclusion, options.except(:in).merge!(rejected_values: formatted_rejected, value: value))
    end
  end
end

