class Kithe::Validators::ModelParent < ActiveModel::Validator
  def validate(record)
    if record.parent.present? && !(record.parent.class <= Kithe::Work)
      record.errors[:parent] << 'must be a Work instance'
    end

    if record.parent.present? && record.class <= Kithe::Collection
      record.errors[:parent] << 'is invalid for Collection instances'
    end

    # TODO avoid recursive parents, maybe using a postgres CTE for efficiency?
  end
end
