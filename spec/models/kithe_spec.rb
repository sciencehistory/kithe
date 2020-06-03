require 'rails_helper'

describe "Kithe module" do
  describe "indexable_settings" do
    it "gets writer_settings.logger set to Rails.logger" do
      expect(Rails.logger).not_to be_nil
      expect(Kithe.indexable_settings.writer_settings["logger"]).to be(Rails.logger)
    end
  end
end
