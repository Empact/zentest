#!/usr/local/bin/ruby -w -I.

$TESTING = false unless defined? $TESTING

class ZenTest

  VERSION = '2.1.0'

  if $TESTING then
    attr_reader :missing_methods
    attr_writer :test_klasses
    attr_writer :klasses
  else
    def missing_methods; raise "Something is wack"; end
  end

  def initialize
    @result = []
    @test_klasses = {}
    @klasses = {}
    @error_count = 0
    @inherited_methods = {}
    @missing_methods = {} # key = klassname, val = array of methods
  end

  def load_file(file)
    puts "# loading #{file} // #{$0}" if $DEBUG
    unless file == $0 then
      begin
	require "#{file}"
      rescue LoadError => err
	puts "Could not load #{file}: #{err}"
      end
    else
      puts "# Skipping loading myself (#{file})" if $DEBUG
    end
  end

  def get_class(klassname)
    begin
      #	p Module.constants
      klass = Module.const_get(klassname.intern)
      puts "# found #{klass.name}" if $DEBUG
    rescue NameError
      # TODO use catch/throw to exit block as soon as it's found?
      # TODO or do we want to look for potential dups?
      ObjectSpace.each_object(Class) { |cls|
	if cls.name =~ /(^|::)#{klassname}$/ then
	  klass = cls
	  klassname = cls.name
	end
      }
      puts "# searched and found #{klass.name}" if klass and $DEBUG
    end

    if klass.nil? and not $TESTING then
      puts "Could not figure out how to get #{klassname}..."
      puts "Report to support-zentest@zenspider.com w/ relevant source"
    end

    return klass
  end

  def get_methods_for(klass)
    klass = self.get_class(klass) if klass.kind_of? String

    public_methods = klass.public_instance_methods
    klassmethods = {}
    public_methods.each do |meth|
      puts "# found method #{meth}" if $DEBUG
      klassmethods[meth] = true
    end
    return klassmethods
  end

  def get_inherited_methods_for(klass)
    klass = self.get_class(klass) if klass.kind_of? String

    klassmethods = {}
    if (klass.class.method_defined?(:superclass)) then
      superklass = klass.superclass
      the_methods = superklass.instance_methods(true)
      
      # generally we don't test Object's methods...
      the_methods -= Object.instance_methods(true)
      
      the_methods.each do |meth|
	klassmethods[meth] = true
      end
    end
    return klassmethods
  end

  def is_test_class(klass)
    klass = klass.to_s
    klasspath = klass.split(/::/)
    a_bad_classpath = klasspath.find do |s| s !~ /^Test/ end
    return a_bad_classpath.nil?
  end

  def convert_class_name(name)
    name = name.to_s

    if self.is_test_class(name) then
      name = name.gsub(/(^|::)Test/, '\1')
    else
      name = name.gsub(/(^|::)/, '\1Test')
    end

    return name
  end

  def scan_files(*files)
    puts "# Code Generated by ZenTest v. #{VERSION}"
    puts "# run against: #{files.join(', ')}" if $DEBUG

    assert_count = {}
    method_count = {}
    assert_count.default = 0
    method_count.default = 0
    klassname = nil

    files.each do |file|
      is_loaded = false
      IO.foreach(file) do |line|

	method_count[klassname] += 1 if klassname and line =~ /^\s*def/
	assert_count[klassname] += 1 if klassname and line =~ /assert|flunk/

	if line =~ /^\s*(?:class|module)\s+(\S+)/ then
	  klassname = $1

	  if line =~ /\#\s*ZenTest SKIP/ then
	    klassname = nil
	    next
	  end

	  unless is_loaded then
	    self.load_file(file)
	    is_loaded = true
	  end

	  klass = self.get_class(klassname)
	  next if klass.nil?
	  klassname = klass.name # refetch to get full name
	  
	  is_test_class = self.is_test_class(klassname)
	  target = is_test_class ? @test_klasses : @klasses

	  # record public instance methods JUST in this class
	  target[klassname] = self.get_methods_for(klass)
	  
	  # record ALL instance methods including superclasses (minus Object)
	  @inherited_methods[klassname] = self.get_inherited_methods_for(klass)
	end # if /class/
      end # IO.foreach
    end # files

    result = []
    method_count.each_key do |classname|

      entry = {}

      next if classname =~ /^Test/
      testclassname = "Test#{classname}"
      a_count = assert_count[testclassname]
      d_count = method_count[classname]
      ratio = a_count.to_f / d_count.to_f * 100.0

      entry['n'] = classname
      entry['r'] = ratio
      entry['a'] = a_count
      entry['d'] = d_count

      result.push entry
    end

    sorted_results = result.sort { |a,b| b['r'] <=> a['r'] }

    printf "# %25s: %4s / %4s = %6s%%\n", "classname", "asrt", "meth", "ratio"
    sorted_results.each do |e|
      printf "# %25s: %4d / %4d = %6.2f%%\n", e['n'], e['a'], e['d'], e['r']
    end

    if $DEBUG then
      puts "# found classes: #{@klasses.keys.join(', ')}"
      puts "# found test classes: #{@test_klasses.keys.join(', ')}"
    end

  end

  def add_missing_method(klassname, methodname)
    @result.push "# ERROR method #{klassname}\##{methodname} does not exist (1)" if $DEBUG and not $TESTING
    @error_count += 1
    @missing_methods[klassname] ||= {}
    @missing_methods[klassname][methodname] = true
  end

  def analyze
    # walk each known class and test that each method has a test method
    @klasses.each_key do |klassname|
      testklassname = self.convert_class_name(klassname)
      if @test_klasses[testklassname] then
	methods = @klasses[klassname]
	testmethods = @test_klasses[testklassname]

	# check that each method has a test method
	@klasses[klassname].each_key do | methodname |
	  testmethodname = "test_#{methodname}".gsub(/\[\]=/, "index_equals").gsub(/\[\]/, "index")
	  unless testmethods[testmethodname] then
	    unless testmethods.keys.find { |m| m =~ /#{testmethodname}(_\w+)+$/ } then
	      self.add_missing_method(testklassname, testmethodname)
	    end
	  end # testmethods[testmethodname]
	end # @klasses[klassname].each_key
      else # ! @test_klasses[testklassname]
	puts "# ERROR test class #{testklassname} does not exist" if $DEBUG
	@error_count += 1

	@missing_methods[testklassname] ||= {}
	@klasses[klassname].keys.each do |meth|
	  # FIX: need to convert method name properly
	  @missing_methods[testklassname]["test_#{meth}"] = true
	end
      end # @test_klasses[testklassname]
    end # @klasses.each_key

    ############################################################
    # now do it in the other direction...

    @test_klasses.each_key do |testklassname|

      klassname = self.convert_class_name(testklassname)

      if @klasses[klassname] then
	methods = @klasses[klassname]
	testmethods = @test_klasses[testklassname]

	# check that each test method has a method
	testmethods.each_key do | testmethodname |
	  # FIX: need to convert method name properly
	  if testmethodname =~ /^test_(.*)/ then
	    methodname = $1.gsub(/index_equals/, "[]=").gsub(/index/, "[]")

	    # TODO think about allowing test_misc_.*

	    # try the current name
	    orig_name = methodname.dup
	    found = false
	    @inherited_methods[klassname] ||= {}
	    until methodname == "" or methods[methodname] or @inherited_methods[klassname][methodname] do
	      # try the name minus an option (ie mut_opt1 -> mut)
	      if methodname.sub!(/_[^_]+$/, '') then
		if methods[methodname] or @inherited_methods[klassname][methodname] then
		  found = true
		end
	      else
		break # no more substitutions will take place
	      end
	    end # methodname == "" or ...

	    unless found or methods[methodname] or methodname == "initialize" then
	      self.add_missing_method(klassname, orig_name)
	    end

	  else # not a test_.* method
	    unless testmethodname =~ /^util_/ then
	      puts "# WARNING Skipping #{testklassname}\##{testmethodname}" if $DEBUG
	    end
	  end # testmethodname =~ ...
	end # testmethods.each_key
      else # ! @klasses[klassname]
	puts "# ERROR class #{klassname} does not exist" if $DEBUG
	@error_count += 1

	@missing_methods[klassname] ||= {}
	@test_klasses[testklassname].keys.each do |meth|
	  # TODO: need to convert method name properly
	  @missing_methods[klassname][meth.sub(/^test_/, '')] = true
	end
      end # @klasses[klassname]
    end # @test_klasses.each_key
  end

  def generate_code

    if @missing_methods.size > 0 then
      @result.push ""
      @result.push "require 'test/unit/testcase'"
      @result.push "require 'zentestrunner'"
      @result.push ""
    end

    indentunit = "  "

    @missing_methods.keys.sort.each do |fullklasspath|

      indent = 0
      is_test_class = self.is_test_class(fullklasspath)
      klasspath = fullklasspath.split(/::/)
      klassname = klasspath.pop

      klasspath.each do | modulename |
	@result.push indentunit*indent + "module #{modulename}"
	indent += 1
      end
      @result.push indentunit*indent + "class #{klassname}" + (is_test_class ? " < Test::Unit::TestCase" : '')
      indent += 1

      methods = @missing_methods[fullklasspath] || {}
      meths = []
      methods.keys.sort.each do |method|
	meth = []
	meth.push indentunit*indent + "def #{method}"
	indent += 1
	meth.push indentunit*indent + "raise NotImplementedError, 'Need to write #{method}'"
	indent -= 1
	meth.push indentunit*indent + "end"
	meths.push meth.join("\n")
      end

      @result.push meths.join("\n\n")

      indent -= 1
      @result.push indentunit*indent + "end"
      klasspath.each do | modulename |
	indent -= 1
	@result.push indentunit*indent + "end"
      end
      @result.push ""
    end

    if @missing_methods.size > 0 then
      @result.push 'if __FILE__ == $0 then'
      @result.push '  run_all_tests_with(ZenTestRunner)'
      @result.push 'end'
      @result.push ''
    end

    @result.push "# Number of errors detected: #{@error_count}"
    @result.push ''
  end

  def result
    return @result.join("\n")
  end

  def ZenTest.fix(*files)
    zentest = ZenTest.new
    zentest.scan_files(*files)
    zentest.analyze
    zentest.generate_code
    return zentest.result
  end

end

if __FILE__ == $0 then
  $TESTING = true # for ZenWeb and any other testing infrastructure code
  print ZenTest.fix(*ARGV)
end
