# -*- encoding: utf-8 -*-
# stub: bundler 2.0.1 ruby lib

Gem::Specification.new do |s|
  s.name = "bundler".freeze
  s.version = "2.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 2.5.0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "http://github.com/bundler/bundler/issues", "changelog_uri" => "https://github.com/bundler/bundler/blob/master/CHANGELOG.md", "homepage_uri" => "https://bundler.io/", "source_code_uri" => "http://github.com/bundler/bundler/" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Andr\u00E9 Arko".freeze, "Samuel Giddins".freeze, "Colby Swandale".freeze, "Hiroshi Shibata".freeze, "David Rodr\u00EDguez".freeze, "Grey Baker".freeze, "Stephanie Morillo".freeze, "Chris Morris".freeze, "James Wen".freeze, "Tim Moore".freeze, "Andr\u00E9 Medeiros".freeze, "Jessica Lynn Suttles".freeze, "Terence Lee".freeze, "Carl Lerche".freeze, "Yehuda Katz".freeze]
  s.bindir = "exe".freeze
  s.date = "2019-01-04"
  s.description = "Bundler manages an application's dependencies through its entire life, across many machines, systematically and repeatably".freeze
  s.email = ["team@bundler.io".freeze]
  s.executables = ["bundle".freeze, "bundler".freeze]
  s.files = ["exe/bundle".freeze, "exe/bundler".freeze]
  s.homepage = "http://bundler.io".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.3.0".freeze)
  s.rubygems_version = "3.0.3".freeze
  s.summary = "The best way to manage your application's dependencies".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<automatiek>.freeze, ["~> 0.1.0"])
      s.add_development_dependency(%q<mustache>.freeze, ["= 0.99.6"])
      s.add_development_dependency(%q<rake>.freeze, ["~> 10.0"])
      s.add_development_dependency(%q<rdiscount>.freeze, ["~> 2.2"])
      s.add_development_dependency(%q<ronn>.freeze, ["~> 0.7.3"])
      s.add_development_dependency(%q<rspec>.freeze, ["~> 3.6"])
    else
      s.add_dependency(%q<automatiek>.freeze, ["~> 0.1.0"])
      s.add_dependency(%q<mustache>.freeze, ["= 0.99.6"])
      s.add_dependency(%q<rake>.freeze, ["~> 10.0"])
      s.add_dependency(%q<rdiscount>.freeze, ["~> 2.2"])
      s.add_dependency(%q<ronn>.freeze, ["~> 0.7.3"])
      s.add_dependency(%q<rspec>.freeze, ["~> 3.6"])
    end
  else
    s.add_dependency(%q<automatiek>.freeze, ["~> 0.1.0"])
    s.add_dependency(%q<mustache>.freeze, ["= 0.99.6"])
    s.add_dependency(%q<rake>.freeze, ["~> 10.0"])
    s.add_dependency(%q<rdiscount>.freeze, ["~> 2.2"])
    s.add_dependency(%q<ronn>.freeze, ["~> 0.7.3"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.6"])
  end
end
