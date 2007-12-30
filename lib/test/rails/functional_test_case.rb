##
# FunctionalTestCase is an abstract class that sets up a controller instance
# for its subclasses.

class Test::Rails::FunctionalTestCase < Test::Rails::TestCase

  ##
  # Sets up instance variables to allow tests depending on a controller work.
  #
  # setup uses the instance variable @controller_class_name to determine which
  # controller class to instantiate.
  #
  # setup also instantiates a new @request and @response object.
  #
  # If you need to perform extra setup actions, define #setup_extra and
  # FunctionalTestCase will call it after performing the rest of its setup
  # actions.

  def setup
    return if self.class.name =~ /TestCase$/

    @controller_class = Object.path2class @controller_class_name
    raise "Can't determine controller class for #{self.class}" if @controller_class.nil?

    @controller = @controller_class.new

    @session = ActionController::TestSession.new

    @flash = ActionController::Flash::FlashHash.new
    @session['flash'] = @flash

    @request = ActionController::TestRequest.new
    @request.session = @session

    @response = ActionController::TestResponse.new

    setup_extra if respond_to? :setup_extra
  end

  ##
  # Flash accessor.  The flash can be assigned to before calling process or
  # render and it will Just Work (yay!)
  #
  # view:
  #   <div class="error"><%= flash[:error] %></div>
  #
  # test:
  #   flash[:error] = 'You did a bad thing.'
  #   render
  #   assert_tag :tag => 'div', :attributes => { :class => 'error' },
  #              :content => 'You did a bad thing.'

  attr_reader :flash

  ##
  # Session accessor.  The session can be assigned to before calling process
  # or render and it will Just Work (yay!)
  #
  # test:
  #
  #   def test_logout
  #     session[:user] = users(:herbert)
  #     post :logout
  #     assert_equal nil, session[:user]
  #   end

  attr_reader :session

end

