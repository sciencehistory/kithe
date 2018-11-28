module Kithe
  # Only one deriv can exist for a given asset_id/key pair, enforced by db constraint.
  class Derivative < ApplicationRecord
    # the fk is to kithe_models STI table, but we only intend for assets
    belongs_to :asset, class_name: "Kithe::Model"
  end
end
