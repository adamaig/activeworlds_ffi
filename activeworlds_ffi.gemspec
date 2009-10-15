# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{activeworlds_ffi}
  s.version = "4.2.77.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.5") if s.respond_to? :required_rubygems_version=
  s.authors = ["Adam Ingram-Goble"]
  s.date = %q{2009-08-08}
  s.description = %q{Ruby FFI based bindings for the ActiveWorlds.com SDK.}
  s.email = %q{adamaig@gmail.com}
  s.extra_rdoc_files = ["README.txt", "LICENSE"]
  s.files = Dir['lib/**/*.rb'] + Dir['examples/**/*'] + ["History.txt", "README.txt", "LICENSE", "PostInstall.txt", "activeworlds_ffi.gemspec"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/adamaig/activeworlds-ffi}
  s.rdoc_options = ["--charset=UTF-8", "--title='ActiveWorlds FFI -- ActiveWorlds SDK applications in Ruby'"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{activeworlds_ffi}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Ruby FFI based bindings for the ActiveWorlds.com SDK, and some support files for making applications simple.}
  s.post_install_message = `cat PostInstall.txt`
  s.add_dependency('ffi', "= 0.3.5")
end
