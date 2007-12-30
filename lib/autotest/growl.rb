# -*- mode -*-

module Autotest::Growl
  def self.growl title, msg, pri=0
    system "growlnotify -n autotest --image /Applications/Mail.app/Contents/Resources/Caution.tiff -p #{pri} -m #{msg.inspect} #{title}"
  end

  Autotest.add_hook :run do  |at|
    growl "Run", "Run" unless $TESTING
  end

  Autotest.add_hook :red do |at|
    growl "Tests Failed", "#{at.files_to_test.size} tests failed", 2
  end

  Autotest.add_hook :green do |at|
    growl "Tests Passed", "All tests passed", -2 if at.tainted 
  end

  Autotest.add_hook :init do |at|
    growl "autotest", "autotest was started" unless $TESTING
  end

  Autotest.add_hook :interrupt do |at|
    growl "autotest", "autotest was reset" unless $TESTING
  end

  Autotest.add_hook :quit do |at|
    growl "autotest", "autotest is exiting" unless $TESTING
  end

  Autotest.add_hook :all do |at|_hook
    growl "autotest", "Tests have fully passed", -2 unless $TESTING
  end
end
