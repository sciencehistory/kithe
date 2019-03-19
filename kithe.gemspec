$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "kithe/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "kithe"
  s.version     = Kithe::VERSION
  s.authors     = ["Jonathan Rochkind"]
  s.email       = ["jrochkind@sciencehistory.org"]
  #s.homepage    = "TODO"
  s.summary     = "An in-progress experiment in shareable tools/components for building a digital collections app in Rails."
  #s.description = "TODO: Description of Kithe."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", ">= 5.2.1", "< 6.1"
  s.add_dependency "attr_json", "< 2.0.0"

  s.add_dependency "simple_form", "~> 4.0"
  s.add_dependency "shrine", "~> 2.14" # file attachment handling
  s.add_dependency "shrine-url", "~> 2.0"
  s.add_dependency "fastimage", "~> 2.0.0" # use by default for image dimensions
  s.add_dependency "marcel" # use by default for content-type detection
  s.add_dependency "pdf-reader", "~> 2.0" # for pdf metadata extraction
  s.add_dependency "tty-command", ">= 0.8.2", "< 2" # still at pre-1.0 when we write this. :(
  s.add_dependency "ruby-progressbar", "~> 1.0"
  s.add_dependency "mini_mime" # already a rails dependency, but we use in derivative filename construction
  s.add_dependency "traject", "~> 3.0" # for Solr or other indexing

  s.add_development_dependency "appraisal" # CI testing under multiple rails versions


  s.add_development_dependency "pg"
  s.add_development_dependency "yard-activesupport-concern"
  s.add_development_dependency "shrine-memory"
  s.add_development_dependency "webmock", "~> 3.0"
end
