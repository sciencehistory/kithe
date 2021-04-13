class Kithe::Validators::ModelParent < ActiveModel::Validator
  def validate(record)
    if record.parent.present? && (record.parent.class <= Kithe::Asset)
      record.errors.add(:parent, 'can not be an Asset instance')
    end

    if record.parent.present? && record.class <= Kithe::Collection
      record.errors.add(:parent, 'is invalid for Collection instances')
    end

    # TODO avoid recursive parents, maybe using a postgres CTE for efficiency?
  end
end
