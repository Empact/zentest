# ActionPack
module ActionController; end
module ActionController::Flash; end
class ActionController::Flash::FlashHash; end
class ActionController::TestSession < Hash; end

class ActionController::TestRequest
  attr_accessor :session
end
class ActionController::TestResponse; end

class ApplicationController; end

module ActionView; end
module ActionView::Helpers; end
module ActionView::Helpers::ActiveRecordHelper; end
module ActionView::Helpers::TagHelper; end
module ActionView::Helpers::FormTagHelper; end
module ActionView::Helpers::FormOptionsHelper; end
module ActionView::Helpers::FormHelper; end
module ActionView::Helpers::UrlHelper; end
module ActionView::Helpers::AssetTagHelper; end

# ActionMailer

module ActionMailer; end
class ActionMailer::Base
  def self.deliveries=(arg); end
end

