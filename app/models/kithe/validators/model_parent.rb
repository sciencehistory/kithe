class Kithe::Validators::ModelParent < ActiveModel::Validator
  def validate(record)
    # don't load the parent just to validate it if it hasn't even changed.
    return unless record.parent_id_changed?

    if record.parent.present? && (record.parent.class <= Kithe::Asset)
      record.errors.add(:parent, 'can not be an Asset instance')
    end

    if record.parent.present? && record.class <= Kithe::Collection
      record.errors.add(:parent, 'is invalid for Collection instances')
    end
  end
end
