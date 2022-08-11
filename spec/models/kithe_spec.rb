require 'rails_helper'

describe "Kithe module" do
  describe "indexable_settings" do
    it "gets writer_settings.logger set to Rails.logger" do
      expect(Rails.logger).not_to be_nil
      expect(Kithe.indexable_settings.writer_settings["logger"]).to be(Rails.logger)
    end

    describe "#writer_settings" do
      it "allows mutation by key" do
        Kithe.indexable_settings.writer_settings["solr_writer.http_timeout"] = 10
        expect(Kithe.indexable_settings.writer_settings["solr_writer.http_timeout"]).to eq(10)
      end

      it "allows mutation by merge!" do
        Kithe.indexable_settings.writer_settings.merge!(
          "solr_writer.solr_update_args" => {}
        )
        expect(Kithe.indexable_settings.writer_settings["solr_writer.solr_update_args"]).to eq({})
      end
    end
  end
end
