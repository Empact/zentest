require 'autotest'

##
# RailsAutotest is an Autotest subclass designed for use with Rails projects.
#
# To use RailsAutotest pass the -rails flag to autotest.

class RailsAutotest < Autotest

  def initialize # :nodoc:
    super
    @exceptions = %r%^\./(?:db|doc|log|public|script|vendor/rails)%
  end

  def map_file_names(updated) # :nodoc:
    model_tests = []
    functional_tests = []

    updated.each do |filename|
      filename.sub!(/^\.\//, '') # trim the ./ that Find gives us

      case filename
      when %r%^test/fixtures/(.*)s.yml% then
        model_tests << "test/unit/#{$1}_test.rb"
        functional_tests << "test/functional/#{$1}_controller_test.rb"
      when %r%^test/unit/.*rb$% then
        model_tests << filename
      when %r%^app/models/(.*)\.rb$% then
        test_file = "test/unit/#{$1}_test.rb"
        model_tests << test_file
      when %r%^test/functional/.*\.rb$% then
        functional_tests << filename
      when %r%^app/helpers/application_helper.rb% then
        functional_test_files = @files.keys.select do |f|
          f =~ %r%^test/functional/.*_test\.rb$%
        end
        functional_tests.push(*functional_test_files.sort)
      when %r%^app/helpers/(.*)_helper.rb% then
        test_file = "test/functional/#{$1}_controller_test.rb"
        functional_tests << test_file
      when %r%^app/controllers/application.rb$% then
        test_file = "test/functional/dummy_controller_test.rb"
        functional_tests << test_file
      when %r%^app/controllers/(.*/)?(.*)\.rb$% then
        test_file = "test/functional/#{$1}#{$2}_test.rb"
        functional_tests << test_file
      when %r%^app/views/layouts/% then
      when %r%^app/views/(.*)/% then
        test_file = "test/functional/#{$1}_controller_test.rb"
        functional_tests << test_file
      when %r%^config/routes.rb$% then
        functional_test_files = @files.keys.select do |f|
          f =~ %r%^test/functional/.*_test\.rb$%
        end
        functional_tests.push(*functional_test_files.sort)
      when %r%^test/test_helper.rb$%,
           %r%^config/boot.rb%,
           %r%^config/database.yml%,
           %r%^config/environment.rb%,
           %r%^config/environments/test.rb% then
        model_test_files = @files.keys.select do |f|
          f =~ %r%^test/unit/.*_test\.rb$%
        end
        functional_test_files = @files.keys.select do |f|
          f =~ %r%^test/functional/.*_test\.rb$%
        end
        model_tests.push(*model_test_files.sort)
        functional_tests.push(*functional_test_files.sort)
      when %r%^vendor/%, /^Rakefile$/ then
        # ignore standard rails files
      else
        STDERR.puts "Dunno! #{filename}" if $v or $TESTING
      end
    end

    model_tests = model_tests.uniq.select { |f| @files.has_key? f }
    functional_tests = functional_tests.uniq.select { |f| @files.has_key? f }

    return model_tests, functional_tests
  end

end

