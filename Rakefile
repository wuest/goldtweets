require 'rake/testtask'

task default: :test

Rake::TestTask.new(:test) do |t|
  t.libs.unshift(File.expand_path(File.join('..', 'test'), __FILE__))
  t.test_files = Dir.glob(File.expand_path(File.join('.', 'test', '**', '*_test.rb')))
  t.ruby_opts << '-I./lib'
end
