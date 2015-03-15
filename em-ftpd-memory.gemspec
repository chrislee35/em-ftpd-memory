# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "em-ftpd-memory"
  spec.version       = "0.0.2"
  spec.authors       = ["chrislee35"]
  spec.email         = ["rubygems@chrislee.dhs.org"]
  spec.summary       = %q{Memory-based backing store for em-ftpd}
  spec.description   = %q{This implements a simple in-memory storage of files for use with em-ftpd}
  spec.homepage      = "https://github.com/chrislee35/em-ftpd-memory"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "em-ftpd", "~> 0.0.1"
  spec.add_runtime_dependency "eventmachine", "~> 1.0.7"
  spec.add_development_dependency "minitest", "~> 5.5"
  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
