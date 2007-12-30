require 'tempfile'

class Tempfile
  # blatently stolen. Design was poor in Tempfile.
  def self.make_tempname(basename, n=10)
    sprintf('%s%d.%d', basename, $$, n)
  end

  def self.make_temppath(basename)
    tempname = ""
    n = 1
    begin
      tmpname = File.join('/tmp', make_tempname(basename, n))
      n += 1
    end while File.exist?(tmpname) and n < 100
    tmpname
  end
end

def temp_file(data)
  temp = 
    if $k then
      File.new(Tempfile.make_temppath("diff"), "w")
    else
      Tempfile.new("diff")
    end
  count = 0
  data = data.map { |l| '%3d) %s' % [count+=1, l] } if $l
  data = data.join('')
  # unescape newlines, strip <> from entire string
  data = data.gsub(/\\n/, "\n").gsub(/0x[a-f0-9]+/m, '0xXXXXXX') + "\n"
  temp.print data
  temp.puts unless data =~ /\n\Z/m
  temp.flush
  temp.rewind
  temp
end

##
# UnitDiff makes reading Test::Unit output easy and fun.  Instead of a
# confusing jumble of text with nearly unnoticable changes like this:
#
#   1) Failure:
#   test_to_gpoints(RouteTest) [test/unit/route_test.rb:29]:
#   <"new GPolyline([\n  new GPoint(  47.00000, -122.00000),\n  new GPoint(  46.5000
#   0, -122.50000),\n  new GPoint(  46.75000, -122.75000),\n  new GPoint(  46.00000,
#    -123.00000)])"> expected but was
#   <"new Gpolyline([\n  new GPoint(  47.00000, -122.00000),\n  new GPoint(  46.5000
#   0, -122.50000),\n  new GPoint(  46.75000, -122.75000),\n  new GPoint(  46.00000,
#    -123.00000)])">.
#
#
# You get an easy-to-read diff output like this:
#
#   1) Failure:
#   test_to_gpoints(RouteTest) [test/unit/route_test.rb:29]:
#   1c1
#   < new GPolyline([
#   ---
#   > new Gpolyline([
#
# == Usage
#
#   test.rb | unit_diff [options]
#     options:
#     -b ignore whitespace differences
#     -c contextual diff
#     -h show usage
#     -k keep temp diff files around
#     -l prefix line numbers on the diffs
#     -u unified diff
#     -v display version

class UnitDiff

  WINDOZE  = /win32/ =~ RUBY_PLATFORM unless defined? WINDOZE
  DIFF = (WINDOZE ? 'diff.exe' : 'diff') unless defined? DIFF

  ##
  # Handy wrapper for UnitDiff#unit_diff.

  def self.unit_diff(input)
    trap 'INT' do exit 1 end
    ud = UnitDiff.new
    ud.unit_diff(input)
  end

  def input(input)
    current = []
    data = []
    data << current

    # Collect
    input.each_line do |line|
      if line =~ /^\s*$/ or line =~ /^\(?\s*\d+\) (Failure|Error):/ then
        type = $1
        current = []
        data << current
      end
      current << line
    end
    data = data.reject { |o| o == ["\n"] }
    header = data.shift
    footer = data.pop
    return header, data, footer
  end

  def parse_diff(result)
    header = []
    expect = []
    butwas = []
    found = false
    state = :header

    until result.empty? do
      case state
      when :header then
        header << result.shift 
        state = :expect if result.first =~ /^</
      when :expect then
        state = :butwas if result.first.sub!(/ expected but was/, '')
        expect << result.shift
      when :butwas then
        butwas = result[0..-1]
        result.clear
      else
        raise "unknown state #{state}"
      end
    end

    return header, expect, nil if butwas.empty?

    expect.last.chomp!
    expect.first.sub!(/^<\"/, '')
    expect.last.sub!(/\">$/, '')

    butwas.last.chomp!
    butwas.last.chop! if butwas.last =~ /\.$/
    butwas.first.sub!( /^<\"/, '')
    butwas.last.sub!(/\">$/, '')

    return header, expect, butwas
  end

  ##
  # Scans Test::Unit output +input+ looking for comparison failures and makes
  # them easily readable by passing them through diff.

  def unit_diff(input)
    $b = false unless defined? $b
    $c = false unless defined? $c
    $k = false unless defined? $k
    $l = false unless defined? $l
    $u = false unless defined? $u

    header, data, footer = self.input(input)

    header = header.map { |l| l.chomp }
    header << nil unless header.empty?

    output = [header]

    # Output
    data.each do |result|
      first = []
      second = []

      if result.first !~ /Failure/ then
        output.push result.join('')
        next
      end

      prefix, expect, butwas = parse_diff(result)

      output.push prefix.compact.map {|line| line.strip}.join("\n")

      if butwas then
        a = temp_file(expect)
        b = temp_file(butwas)

        diff_flags = $u ? "-u" : $c ? "-c" : ""
        diff_flags += " -b" if $b

        result = `#{DIFF} #{diff_flags} #{a.path} #{b.path}`
        if result.empty? then
          output.push "[no difference--suspect ==]"
        else
          output.push result.map { |line| line.chomp }
        end

        output.push ''
      else
        output.push expect.join('')
      end
    end

    if footer then
      footer.shift if footer.first.strip.empty?
      output.push footer.compact.map {|line| line.strip}.join("\n")
    end

    return output.flatten.join("\n")
  end

end

