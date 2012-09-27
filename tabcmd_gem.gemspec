#encoding: UTF-8
Gem::Specification.new do |s|
  s.name          = "tabcmd_gem"
  s.email         = "bliu@pivotallabs.com "
  s.version       = "0.0.1"
  s.date          = "2012-09-25"
  s.description   = "Description"
  s.summary       = "Summary"
  s.authors       = ["Brandon Liu and Daniel Onggunhao"]
  s.homepage      = "http://pivotallabs.com"
  s.license       = "NONE"

  # files = []
  # files << "readme.md"
  # files << Dir["sql/**/*.sql"]
  # files << Dir["{lib,test}/**/*.rb"]
  # s.files = files
  # s.test_files = s.files.select {|path| path =~ /^test\/.*_test.rb/}

  s.require_paths = %w[tabcmd]
  s.add_dependency "log4r"
  s.add_dependency "rchardet19"
  s.add_dependency "hpricot"
  s.add_dependency "highline"
end