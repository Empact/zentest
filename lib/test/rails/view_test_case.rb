##
# RailsViewTestCase allows views to be tested independent of their
# controllers.  Testcase implementors must set up the instance variables the
# view needs to render itself.
#
# == Naming
#
# The test class must be named +ControllerViewTest+, so if you're testing
# views for the +RouteController+ you would name your test case
# +RouteViewTest+.  The test case will expect to find your view files in
# +app/views/route/+.
#
# The test names should be +test_viewname_extra+ where the viewname
# corresponds to the name of the view file.  If you are testing a view file
# named 'show.rhtml' your test should be named +test_show+.  If your view is
# behaves differently depending upon its arguments you can make the test name
# descriptive with extra arguments like +test_show_photos+ and
# +test_show_no_photos+.
#
# If there is behavior tied to a different controller action you should name
# your test after that action and use the :action option for render.  This
# aids in automatic auditing of testing between controllers and views.  For
# example, if the controller action +create+ may render the +new+ action on
# invalid arguments the test should be named +test_create+ and you should call
# +render :action => 'new'+.
#
# == Examples
#
#   class RouteViewTest < Test::Rails::ViewTestCase
#   
#     fixtures :users, :routes, :points, :photos
#   
#     def test_delete
#       controller[:loggedin_user] = users(:herbert)
#       controller[:route] = routes(:work)
#   
#       render
#   
#       form_url = '/route/destroy'
#       assert_post_form form_url
#       assert_input form_url, :hidden, :id
#       assert_submit form_url, 'Delete!'
#       assert_links_to "/route/show/#{routes(:work).id}", 'No, I do not!'
#     end
#   
#   end
#
# === Testing Layouts
#
# TODO: render :layout => 'home', :text => '' to get around 'no such file'
#       error

class Test::Rails::ViewTestCase < Test::Rails::ControllerTestCase

  ##
  # Sets up the test case.

  def setup
    return if self.class == Test::Rails::ViewTestCase
    super
    @ivar_proxy = Test::Rails::IvarProxy.new @controller

    # these go here so that flash and session work as they should.
    @controller.send :initialize_template_class, @response
    @controller.send :assign_shortcuts, @request, @response
    @controller.send :reset_session

    controller[:session] = @controller.session
    @controller.class.send :public, :flash # make flash accessible to the test
  end

  ##
  # Allows the view instance variables to be set like flash:
  #
  # test:
  #   def test_show
  #     controller[:route] = routes(:work)

  def controller
    @ivar_proxy
  end

  ##
  # Renders the template.  The template is determined from the test name.  If
  # you have multiple tests for the same view render will try to Do The Right
  # Thing and remove parts of the name looking for the template file.
  #
  # The action can be forced by using the options:
  #
  #   render :action => 'new'
  #
  #   render :template => 'profile/index'
  #
  # For this test:
  #   class RouteViewTest < RailsViewTestCase
  #     def test_show_photos
  #       render
  #     end
  #     def test_show_no_photos
  #       render
  #     end
  #   end
  #
  # For test_show_photos will look for:
  # * app/views/route/show_photos.rhtml
  # * app/views/route/show_photos.rxml
  # * app/views/route/show.rhtml
  # * app/views/route/show.rxml
  #
  # And test_show_no_photos will look for:
  # * app/views/route/show_no_photos.rhtml
  # * app/views/route/show_no_photos.rxml
  # * app/views/route/show_no.rhtml
  # * app/views/route/show_no.rxml
  # * app/views/route/show.rhtml
  # * app/views/route/show.rxml
  #
  # If a view cannot be found the test will flunk.

  def render(options = {}, deprecated_status = nil)
    @action_name = action_name caller[0] if options.empty?
    controller[:action_name] = @action_name

    @request.path_parameters = {
      :controller => @controller.controller_name,
      :action => @action_name,
    }

    defaults = { :layout => false }
    options = defaults.merge options
    @controller.send :initialize_current_url

    # Rails 1.0
    @controller.send :assign_names rescue nil
    @controller.send :fire_flash rescue nil

    # Rails 1.1
    @controller.send :forget_variables_added_to_assigns rescue nil

    # Do the render
    @controller.render options, deprecated_status

    # Rails 1.1
    @controller.send :process_cleanup rescue nil
  end

  ##
  # Flash accessor.  Flash can be assigned to before calling render and it
  # will Just Work (yay!)
  #
  # view:
  #   <div class="error"><%= flash[:error] %></div>
  #
  # test:
  #   flash[:error] = 'You did a bad thing.'
  #   render
  #   assert_tag :tag => 'div', :attributes => { :class => 'error' },
  #              :content => 'You did a bad thing.'

  def flash
    return @controller.flash
  end

  ##
  # Asserts that there is an error on +field+ of type +type+.

  def assert_error_on(field, type)
    error_message = ActiveRecord::Errors.default_error_messages[type]
    assert_tag :tag => 'div', :attributes => { :class => 'errorExplanation' },
                  :descendant => {
                    :tag => 'li',
                    :content => /^#{field} #{error_message}/i }
  end

  ##
  # Asserts that a form with +form_action+ has an input element of +type+ with
  # a name of "+model+[+column+]" and has a label with a for attribute of
  # "+model+_+column+".
  #
  # view:
  #   <%= start_form_tag :controller => 'game', :action => 'save' %>
  #   <label for="game_amount">Amount:</label>
  #   <% text_field 'game', 'amount' %>
  #
  # test:
  #   assert_field '/game/save', :text, :game, :amount

  def assert_field(form_action, type, model, column, value = nil)
    assert_input form_action, type, "#{model}[#{column}]", value
    assert_label form_action, "#{model}_#{column}", false
  end

  ##
  # Asserts that an image exists with a src of +src+.
  #
  # view:
  #   <img src="/images/bucket.jpg" alt="Bucket">
  #
  # test:
  #   assert_image '/images/bucket.jpg'

  def assert_image(src)
    assert_tag :tag => 'img', :attributes => { :src => src }
  end

  ##
  # Asserts that a form with +form_action+ has an input element of +type+ with
  # a name of +name+.
  #
  # view:
  #   <%= start_form_tag :controller => 'game', :action => 'save' %>
  #   <%= text_field 'game', 'amount' %>
  #
  # test:
  #   assert_input '/game/save', :text, "game[amount]"

  def assert_input(form_action, type, name, value = nil)
    attrs = { :type => type.to_s, :name => name.to_s }
    attrs[:value] = value unless value.nil?
    assert_tag_in_form form_action, :tag => 'input', :attributes => attrs
  end

  ##
  # Asserts that a form with +form_action+ has a label with a for attribute of
  # "+model+_+column+".
  #
  # view:
  #   <%= start_form_tag :controller => 'game', :action => 'save' %>
  #   <label for="game_amount">Amount:</label>
  #
  # test:
  #   assert_label '/game/save', :game, :amount

  def assert_label(form_action, name, include_f = true)
    for_attribute = (include_f ? 'f_' : '') << name
    assert_tag_in_form form_action, :tag => 'label', :attributes => {
                                      :for => for_attribute }
  end

  ##
  # Asserts that there is an anchor tag with an href of +href+ and optionally
  # has +content+.
  #
  # view:
  #   <%= link_to 'drbrain', :model => user %>
  #
  # test:
  #   assert_links_to '/players/show/1', 'drbrain'

  def assert_links_to(href, content = nil)
    assert_tag links_to_options_for(href, content)
  end

  ##
  # Denies the existence of an anchor tag with an href of +href+ and
  # optionally +content+.
  #
  # view (for /players/show/1):
  #   <%= link_to_unless_current 'drbrain', :model => user %>
  #
  # test:
  #   deny_links_to '/players/show/1'

  def deny_links_to(href, content = nil)
    assert_no_tag links_to_options_for(href, content)
  end

  ##
  # Asserts that there is a form using the 'POST' method whose action is
  # +form_action+ and uses the multipart content type.
  #
  # view:
  #   <%= start_form_tag({ :action => 'create_file' }, :multipart => true) %>
  #
  # test:
  #   assert_multipart_form '/game/save'

  def assert_multipart_form(form_action)
    assert_tag :tag => 'form', :attributes => { :action => form_action,
                 :method => 'post', :enctype => 'multipart/form-data' }
  end

  ##
  # Asserts that there is a form using the 'POST' method whose action is
  # +form_action+.
  #
  # view:
  #   <%= start_form_tag :action => 'create_file' %>
  #
  # test:
  #   assert_post_form '/game/save'

  def assert_post_form(form_action)
    assert_tag :tag => 'form', :attributes => { :action => form_action,
                 :method => 'post' }
  end

  ##
  # Asserts that a form with +form_action+ has a select element with a name of
  # "+model+[+column+]" and options with specified names and values.
  #
  # view:
  #   <%= start_form_tag :action => 'save' %>
  #   <%= collection_select :game, :location_id, @locations, :id, :name %>
  #
  # test:
  #   assert_select '/games/save', :game, :location_id,
  #                 'Ballet' => 1, 'Guaymas' => 2

  def assert_select(form_action, model, column, options)
    assert_kind_of Hash, options, "options needs to be a Hash"
    deny options.empty?, "options must not be empty"
    options.each do |option_name, option_id|
      assert_tag_in_form(form_action,
                         :tag => 'select',
                         :attributes => { :name => "#{model}[#{column}]" },
                         :child => {
                           :tag => 'option',
                           :attributes => { :value => option_id },
                           :content => option_name
                         })
    end
  end

  ##
  # Asserts that a form with +form_action+ has a submit element with a value
  # of +value+.
  #
  # view:
  #   <%= start_form_tag :action => 'save' %>
  #   <input type="submit" value="Create!" %>
  #
  # test:
  #   assert_submit '/route/save', 'Create!'

  def assert_submit(form_action, value)
    assert_tag_in_form form_action, :tag => 'input', :attributes => {
                                      :type => "submit", :value => value }
  end

  ##
  # Asserts that a form with +form_action+ has a descendent that matches
  # +options+.
  #
  # Typically this is not used directly in tests.  Instead use it to build
  # expressive tests that assert which fields are in what form.
  #
  # view:
  #   <%= start_form_tag :action => 'save' %>
  #   <table>
  #
  # test:
  #   assert_tag_in_form '/route/save', :tag => 'table'

  def assert_tag_in_form(form_action, options)
    assert_tag :tag => 'form', :attributes => { :action => form_action },
                 :descendant => options
  end

  def util_make_paginator(item_count, items_per_page, page_number)
    ActionController::Pagination::Paginator.new(@controller, item_count,
                                                items_per_page, page_number)
  end

  protected

  ##
  # Creates an assertion options hash for +href+ and +content+.

  def links_to_options_for(href, content = nil)
    options = { :tag => 'a', :attributes => { :href => href } }
    options[:content] = content unless content.nil?
    return options
  end

  private

  ##
  # Returns the action_name based on a backtrace line passed in as +test+.

  def action_name(test)
    orig_name = test = test.sub(/.*in `test_(.*)'/, '\1')
    controller = @controller.class.name.sub('Controller', '')
    controller = controller.gsub(/([A-Z])/, '_\1'.downcase).sub('_', '')
    
    while test =~ /_/ do
      return test if File.file? "app/views/#{controller}/#{test}.rhtml"
      return test if File.file? "app/views/#{controller}/#{test}.rxml"
      test = test.sub(/_[^_]+$/, '')
    end

    return test if File.file? "app/views/#{controller}/#{test}.rhtml"
    return test if File.file? "app/views/#{controller}/#{test}.rxml"

    flunk "Couldn't find view for test_#{orig_name}"
  end

end

