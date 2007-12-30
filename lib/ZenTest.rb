$stdlib = {}
ObjectSpace.each_object(Module) { |m| $stdlib[m.name] = true }

$:.unshift( *$I.split(/:/) ) if defined? $I and String === $I
$r = false unless defined? $r # reverse mapping for testclass names

if $r then
  $-w = false # rails is retarded
  $: << 'config'
  require 'environment'
end

$ZENTEST = true
$TESTING = true

require 'test/unit/testcase' # helps required modules

class Module

  def zentest
    at_exit { ZenTest.autotest(self) }
  end

end

class ZenTest

  VERSION = '3.0.0'

  if $TESTING then
    attr_reader :missing_methods
    attr_accessor :test_klasses
    attr_accessor :klasses
    attr_accessor :inherited_methods
  else
    def missing_methods; raise "Something is wack"; end
  end

  def initialize
    @result = []
    @test_klasses = {}
    @klasses = {}
    @error_count = 0
    @inherited_methods = Hash.new { |h,k| h[k] = {} }
    # key = klassname, val = hash of methods => true
    @missing_methods = Hash.new { |h,k| h[k] = {} }
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
      klass = Module.const_get(klassname.intern)
      puts "# found class #{klass.name}" if $DEBUG
    rescue NameError
      ObjectSpace.each_object(Class) do |cls|
	if cls.name =~ /(^|::)#{klassname}$/ then
	  klass = cls
	  klassname = cls.name
          break
	end
      end
      puts "# searched and found #{klass.name}" if klass and $DEBUG
    end

    if klass.nil? and not $TESTING then
      puts "Could not figure out how to get #{klassname}..."
      puts "Report to support-zentest@zenspider.com w/ relevant source"
    end

    return klass
  end

  def get_methods_for(klass, full=false)
    klass = self.get_class(klass) if klass.kind_of? String

    # WTF? public_instance_methods: default vs true vs false = 3 answers
    public_methods = klass.public_instance_methods(false)
    klass_methods = klass.singleton_methods(full)
    klass_methods -= Class.public_methods(true)
    klass_methods -= %w(suite new)
    klass_methods = klass_methods.map { |m| "self." + m }
    public_methods += klass_methods
    public_methods -= Kernel.methods unless full
    klassmethods = {}
    public_methods.each do |meth|
      puts "# found method #{meth}" if $DEBUG
      klassmethods[meth] = true
    end

    return klassmethods
  end

  def get_inherited_methods_for(klass, full)
    klass = self.get_class(klass) if klass.kind_of? String

    klassmethods = {}
    if (klass.class.method_defined?(:superclass)) then
      superklass = klass.superclass
      if superklass then
        the_methods = superklass.instance_methods(true)
        
        # generally we don't test Object's methods...
        unless full then
          the_methods -= Object.instance_methods(true)
          the_methods -= Kernel.methods # FIX (true) - check 1.6 vs 1.8
        end
      
        the_methods.each do |meth|
          klassmethods[meth] = true
        end
      end
    end
    return klassmethods
  end

  def is_test_class(klass)
    klass = klass.to_s
    klasspath = klass.split(/::/)
    a_bad_classpath = klasspath.find do |s| s !~ ($r ? /Test$/ : /^Test/) end
    return a_bad_classpath.nil?
  end

  def convert_class_name(name)
    name = name.to_s

    if self.is_test_class(name) then
      if $r then
        name = name.gsub(/Test($|::)/, '\1') # FooTest::BlahTest => Foo::Blah
      else
        name = name.gsub(/(^|::)Test/, '\1') # TestFoo::TestBlah => Foo::Blah
      end
    else
      if $r then
        name = name.gsub(/($|::)/, 'Test\1') # Foo::Blah => FooTest::BlahTest
      else
        name = name.gsub(/(^|::)/, '\1Test') # Foo::Blah => TestFoo::TestBlah
      end
    end

    return name
  end

  def process_class(klassname, full=false)
    klass = self.get_class(klassname)
    raise "Couldn't get class for #{klassname}" if klass.nil?
    klassname = klass.name # refetch to get full name
    
    is_test_class = self.is_test_class(klassname)
    target = is_test_class ? @test_klasses : @klasses

    # record public instance methods JUST in this class
    target[klassname] = self.get_methods_for(klass, full)
    
    # record ALL instance methods including superclasses (minus Object)
    @inherited_methods[klassname] = self.get_inherited_methods_for(klass, full)
    return klassname
  end

  def scan_files(*files)
    assert_count = Hash.new(0)
    method_count = Hash.new(0)
    klassname = nil

    files.each do |path|
      is_loaded = false

      # if reading stdin, slurp the whole thing at once
      file = (path == "-" ? $stdin.read : File.new(path))

      file.each_line do |line|

        if klassname then
          case line
          when /^\s*def/ then
            method_count[klassname] += 1
          when /assert|flunk/ then
            assert_count[klassname] += 1
          end
        end

	if line =~ /^\s*(?:class|module)\s+([\w:]+)/ then
	  klassname = $1

	  if line =~ /\#\s*ZenTest SKIP/ then
	    klassname = nil
	    next
	  end

          full = false
	  if line =~ /\#\s*ZenTest FULL/ then
	    full = true
	  end

	  unless is_loaded then
            unless path == "-" then
              self.load_file(path)
            else
              eval file, TOPLEVEL_BINDING
            end
            is_loaded = true
	  end

          begin
            klassname = self.process_class(klassname, full)
          rescue
            puts "# Couldn't find class for name #{klassname}"
            next
          end

          # Special Case: ZenTest is already loaded since we are running it
          if klassname == "TestZenTest" then
            klassname = "ZenTest"
            self.process_class(klassname, false)
          end

	end # if /class/
      end # IO.foreach
    end # files

    result = []
    method_count.each_key do |classname|

      entry = {}

      next if is_test_class(classname)
      testclassname = convert_class_name(classname)
      a_count = assert_count[testclassname]
      m_count = method_count[classname]
      ratio = a_count.to_f / m_count.to_f * 100.0

      entry['n'] = classname
      entry['r'] = ratio
      entry['a'] = a_count
      entry['m'] = m_count

      result.push entry
    end

    sorted_results = result.sort { |a,b| b['r'] <=> a['r'] }

    @result.push sprintf("# %25s: %4s / %4s = %6s%%", "classname", "asrt", "meth", "ratio")
    sorted_results.each do |e|
      @result.push sprintf("# %25s: %4d / %4d = %6.2f%%", e['n'], e['a'], e['m'], e['r'])
    end
  end

  def add_missing_method(klassname, methodname)
    @result.push "# ERROR method #{klassname}\##{methodname} does not exist (1)" if $DEBUG and not $TESTING
    @error_count += 1
    @missing_methods[klassname][methodname] = true
  end

  @@orig_method_map = {
    '!'   => 'bang',
    '%'   => 'percent',
    '&'   => 'and',
    '*'   => 'times',
    '**'  => 'times2',
    '+'   => 'plus',
    '-'   => 'minus',
    '/'   => 'div',
    '<'   => 'lt',
    '<='  => 'lte',
    '<=>' => 'spaceship',
    "<\<" => 'lt2',
    '=='  => 'equals2',
    '===' => 'equals3',
    '=~'  => 'equalstilde',
    '>'   => 'gt',
    '>='  => 'ge',
    '>>'  => 'gt2',
    '@+'  => 'unary_plus',
    '@-'  => 'unary_minus',
    '[]'  => 'index',
    '[]=' => 'index_equals',
    '^'   => 'carat',
    '|'   => 'or',
    '~'   => 'tilde',
  }

  @@method_map = @@orig_method_map.merge(@@orig_method_map.invert)

  def normal_to_test(name)
    name = name.dup # wtf?
    is_cls_method = name.sub!(/^self\./, '')
    name = @@method_map[name] if @@method_map.has_key? name
    name = name.sub(/=$/, '_equals')
    name = name.sub(/\?$/, '_eh')
    name = name.sub(/\!$/, '_bang')
    name = "class_" + name if is_cls_method
    "test_#{name}"
  end

  def test_to_normal(name, klassname=nil)
    known_methods = (@inherited_methods[klassname] || {}).keys.sort.reverse

    mapped_re = @@orig_method_map.values.sort_by { |k| k.length }.map {|s| Regexp.escape(s)}.reverse.join("|")
    known_methods_re = known_methods.map {|s| Regexp.escape(s)}.join("|")

    name = name.sub(/^test_/, '')
    name = name.sub(/_equals/, '=') unless name =~ /index/
    name = name.sub(/_bang.*$/, '!') # FIX: deal w/ extensions separately
    name = name.sub(/_eh/, '?')
    is_cls_method = name.sub!(/^class_/, '')
    name = name.sub(/^(#{mapped_re})(.*)$/) {$1}
    name = name.sub(/^(#{known_methods_re})(.*)$/) {$1} unless known_methods_re.empty?

    # look up in method map
    name = @@method_map[name] if @@method_map.has_key? name

    name = 'self.' + name if is_cls_method

    name
  end

  def analyze_impl(klassname)
    testklassname = self.convert_class_name(klassname)
    if @test_klasses[testklassname] then
      methods = @klasses[klassname]
      testmethods = @test_klasses[testklassname]

      # check that each method has a test method
      @klasses[klassname].each_key do | methodname |
        testmethodname = normal_to_test(methodname)
        unless testmethods[testmethodname] then
          begin
            unless testmethods.keys.find { |m| m =~ /#{testmethodname}(_\w+)+$/ } then
              self.add_missing_method(testklassname, testmethodname)
            end
          rescue RegexpError => e
            puts "# ERROR trying to use '#{testmethodname}' as a regex. Look at #{klassname}.#{methodname}"
          end
        end # testmethods[testmethodname]
      end # @klasses[klassname].each_key
    else # ! @test_klasses[testklassname]
      puts "# ERROR test class #{testklassname} does not exist" if $DEBUG
      @error_count += 1

      @klasses[klassname].keys.each do | methodname |
        self.add_missing_method(testklassname, normal_to_test(methodname))
      end
    end # @test_klasses[testklassname]
  end

  def analyze_test(testklassname)
    klassname = self.convert_class_name(testklassname)

    # CUT might be against a core class, if so, slurp it and analyze it
    if $stdlib[klassname] then
      self.process_class(klassname, true)
      self.analyze_impl(klassname)
    end

    if @klasses[klassname] then
      methods = @klasses[klassname]
      testmethods = @test_klasses[testklassname]

      # check that each test method has a method
      testmethods.each_key do | testmethodname |
        if testmethodname =~ /^test_(?!integration_)/ then

          # try the current name
          methodname = test_to_normal(testmethodname, klassname)
          orig_name = methodname.dup

          found = false
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

      @test_klasses[testklassname].keys.each do |testmethodname|
        @missing_methods[klassname][test_to_normal(testmethodname)] = true
      end
    end # @klasses[klassname]
  end

  def analyze
    # walk each known class and test that each method has a test method
    @klasses.each_key do |klassname|
      self.analyze_impl(klassname)
    end

    # now do it in the other direction...
    @test_klasses.each_key do |testklassname|
      self.analyze_test(testklassname)
    end
  end

  def generate_code

#    @result.unshift "# run against: #{files.join(', ')}" if $DEBUG
    @result.unshift "# Code Generated by ZenTest v. #{VERSION}"

    if $DEBUG then
      @result.push "# found classes: #{@klasses.keys.join(', ')}"
      @result.push "# found test classes: #{@test_klasses.keys.join(', ')}"
    end

    if @missing_methods.size > 0 then
      @result.push ""
      @result.push "require 'test/unit' unless defined? $ZENTEST and $ZENTEST"
      @result.push ""
    end

    indentunit = "  "

    @missing_methods.keys.sort.each do |fullklasspath|

      methods = @missing_methods[fullklasspath]
      cls_methods = methods.keys.grep(/^(self\.|test_class_)/)
      methods.delete_if {|k,v| cls_methods.include? k }

      next if methods.empty? and cls_methods.empty?

      indent = 0
      is_test_class = self.is_test_class(fullklasspath)
      klasspath = fullklasspath.split(/::/)
      klassname = klasspath.pop

      klasspath.each do | modulename |
        m = self.get_class(modulename)
        type = m.nil? ? "module" : m.class.name.downcase
	@result.push indentunit*indent + "#{type} #{modulename}"
	indent += 1
      end
      @result.push indentunit*indent + "class #{klassname}" + (is_test_class ? " < Test::Unit::TestCase" : '')
      indent += 1

      meths = []

      cls_methods.sort.each do |method|
	meth = []
	meth.push indentunit*indent + "def #{method}"
        meth.last << "(*args)" unless method =~ /^test/
	indent += 1
	meth.push indentunit*indent + "raise NotImplementedError, 'Need to write #{method}'"
	indent -= 1
	meth.push indentunit*indent + "end"
	meths.push meth.join("\n")
      end

      methods.keys.sort.each do |method|
        next if method =~ /pretty_print/
	meth = []
	meth.push indentunit*indent + "def #{method}"
        meth.last << "(*args)" unless method =~ /^test/
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
      @result.push ''
    end

    @result.push "# Number of errors detected: #{@error_count}"
    @result.push ''
  end

  def result
    return @result.join("\n")
  end

  def self.fix(*files)
    zentest = ZenTest.new
    zentest.scan_files(*files)
    zentest.analyze
    zentest.generate_code
    return zentest.result
  end

  def self.autotest(*klasses)
    zentest = ZenTest.new
    klasses.each do |klass|
      zentest.process_class(klass)
    end

    zentest.analyze

    zentest.missing_methods.each do |klass,methods|
      methods.each do |method,x|
        warn "autotest generating #{klass}##{method}"
      end
    end

    zentest.generate_code
    code = zentest.result
    puts code if $DEBUG

    Object.class_eval code
  end
end

