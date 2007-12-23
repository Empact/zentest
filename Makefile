RUBY?=ruby
RUBYFLAGS?=

test: unittest
	-$(RUBY) $(RUBYFLAGS) ./ZenTest.rb testcase0.rb > tmp.txt; diff testcase0.result tmp.txt
	-$(RUBY) $(RUBYFLAGS) ./ZenTest.rb testcase1.rb > tmp.txt; diff testcase1.result tmp.txt
	-$(RUBY) $(RUBYFLAGS) ./ZenTest.rb testcase2.rb > tmp.txt; diff testcase2.result tmp.txt
	-$(RUBY) $(RUBYFLAGS) ./ZenTest.rb testcase3.rb > tmp.txt; diff testcase3.result tmp.txt
	-$(RUBY) $(RUBYFLAGS) ./ZenTest.rb testcase4.rb > tmp.txt; diff testcase4.result tmp.txt
	-$(RUBY) $(RUBYFLAGS) ./ZenTest.rb testcase5.rb > tmp.txt; diff testcase5.result tmp.txt
	-rm -f tmp.txt

unittest:
	$(RUBY) $(RUBYFLAGS) ./TestZenTest.rb


clean:
	rm -f *~
