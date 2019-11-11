require 'rails_helper'

# Mocks the actual shell-out, yeah we're not testing that we don't want
# to have to install mediainfo on travis. A mistake? We'll see.
describe Kithe::MediainfoAnalyzer do
  let(:io) { StringIO.new("fakecontnet") }
  let(:analyzer) { Kithe::MediainfoAnalyzer.new }

  describe "when mediainfo knows mime-type" do
    let(:content_type) { "audio/mpeg" }

    before do
      allow(analyzer.send(:tty_command)).to receive(:run).
        with('mediainfo --Inform="General;%InternetMediaType%"', /.*/).
        and_return(content_type)
    end

    it "returns mime_type" do
      expect(analyzer.call(io)).to eq(content_type)
    end

    it "rewinds" do
      expect(analyzer.call(io))
      expect(io.lineno).to eq(0)
    end
  end

  describe "when mediainfo does not know mime-type" do
    before do
      allow(analyzer.send(:tty_command)).to receive(:run).and_return("\n")
    end

    it "returns mime_type" do
      expect(analyzer.call(io)).to eq(nil)
    end
  end

end
