require 'rubygems'  
SPEC=Gem::Specification.new do |s|  
	s.homepage = 'http://github.com/burmajam/SimpleMachine'
	s.rubyforge_project = "simple_machine"
	s.name = 'simple_machine'
	s.version = '1.0.1'
	s.author = 'Milan Burmaja'  
	s.email = 'burmajam@gmail.com'
	s.platform = Gem::Platform::RUBY  
	s.summary = "SimpleMachine is module for Ruby which injects simple state machine behavior in any class that includes it"
	s.files = %w(README.rdoc lib/simple_machine.rb spec/spec_simple_machine.rb)
	s.require_path = 'lib'
	s.has_rdoc = true
end