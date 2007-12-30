require 'code_statistics'

namespace :test do
  desc 'Run the view tests in test/views'
  Rake::TestTask.new :views => [ 'db:test:prepare' ] do |t|
    t.libs << 'test'
    t.pattern = 'test/views/**/*_test.rb'
    t.verbose = true
  end

  desc 'Run the controller tests in test/controllers'
  Rake::TestTask.new :controllers => [ 'db:test:prepare' ] do |t|
    t.libs << 'test'
    t.pattern = 'test/controllers/**/*_test.rb'
    t.verbose = true
  end
end

desc 'Run all tests'
task :test => %w[
  test:units
  test:controllers
  test:views
  test:functionals
  test:integration
]

dirs = [
  %w[Libraries          lib/],
  %w[Models             app/models],
  %w[Unit\ tests        test/unit],
  %w[Components         components],
  %w[Controllers        app/controllers],
  %w[Controller\ tests  test/controllers],
  %w[View\ tests        test/views],
  %w[Functional\ tests  test/functional],
  %w[Integration\ tests test/integration],
  %w[APIs               app/apis],
  %w[Helpers            app/helpers],
]

dirs = dirs.map { |name, dir| [name, File.join(RAILS_ROOT, dir)] }
dirs = dirs.select { |name, dir| File.directory? dir }

STATS_DIRECTORIES.replace dirs

CodeStatistics::TEST_TYPES << 'View tests'
CodeStatistics::TEST_TYPES << 'Controller tests'

