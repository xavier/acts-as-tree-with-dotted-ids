
$:.reject! { |e| e.include? 'TextMate' } 

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test acts_as_tree plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for acts_as_tree plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'acts_as_tree_with_dotted_ids'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "acts-as-tree-with-dotted-ids"
    gem.summary = %Q{A drop in replacement for acts_as_tree with super fast ancestors and subtree access}
    gem.description = %Q{}
    gem.email = "tma@freshbit.ch"
    gem.homepage = "http://github.com/tma/acts-as-tree-with-dotted-ids"
    gem.authors = ["David Heinemeier Hansson", "Xavier Defrang"]
    gem.files = Dir.glob('lib/**/*.rb')
    gem.add_dependency "activerecord", '>= 3.0.0'
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end
