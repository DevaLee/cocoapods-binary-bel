# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-binary/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-binary'
  spec.version       = CocoapodsBinary::VERSION
  spec.authors       = ['leavez']
  spec.email         = ['gaojiji@gmail.com']
  spec.description   = %q{integrate pods in form of prebuilt frameworks conveniently, reducing compile time}
  spec.summary       = %q{A CocoaPods plugin to integrate pods in form of prebuilt frameworks, not source code, by adding just one flag in podfile. Speed up compiling dramatically.}
  spec.homepage      = 'https://github.com/leavez/cocoapods-binary'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/).reject{|f| f.start_with?("test/") || f.start_with?('demo/')}
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency "cocoapods"
  spec.add_runtime_dependency "fourflusher"
  spec.add_runtime_dependency "xcpretty"

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
end
