# -*- encoding: utf-8 -*-
$:.unshift File.expand_path('../lib', __FILE__)

require 'version'


Gem::Specification.new do |s|
  s.name = 'cocaine'
  s.version = Cocaine::VERSION
  s.homepage = 'https://github.com/cocaine-framework-ruby'
  s.licenses = ['Ruby', 'LGPLv3']

  s.authors = ['Evgeny Safronov']
  s.email   = ['division494@gmail.com']

  s.files = `git ls-files`.split("\n")
  s.extensions = []

  s.summary = 'Ruby/Cocaine library'
  s.description = "Cocaine Framework is a framework for simplifying development both server-side
and client-side applications. It's pretty nice, I promise."
end