require 'turbolinks/version'
require 'turbolinks/xhr_headers'
require 'turbolinks/xhr_redirect'
require 'turbolinks/xhr_url_for'
require 'turbolinks/cookies'
require 'turbolinks/x_domain_blocker'
require 'turbolinks/redirection'
require 'turbolinks/helpers'
require 'turbolinks/configuration'
require 'turbolinks/kbuilder_template'
require 'turbolinks/digestor'

module Turbolinks
  module Controller
    include XHRHeaders, Cookies, XDomainBlocker, Redirection, Helpers

    def self.included(base)
      if base.respond_to?(:before_action)
        base.before_action :set_xhr_redirected_to, :set_request_method_cookie
        base.after_action :abort_xdomain_redirect
      else
        base.before_filter :set_xhr_redirected_to, :set_request_method_cookie
        base.after_filter :abort_xdomain_redirect
      end

      if base.respond_to?(:helper_method)
        base.helper_method :turbolinks_tag
      end
    end
  end

  class Engine < ::Rails::Engine
    config.turbolinks = ActiveSupport::OrderedOptions.new
    config.turbolinks.auto_include = true

    initializer :turbolinks do |app|
      ActiveSupport.on_load(:action_controller) do
        next if self != ActionController::Base

        if app.config.turbolinks.auto_include
          include Controller
        end

        ActionDispatch::Request.class_eval do
          def referer
            self.headers['X-XHR-Referer'] || super
          end
          alias referrer referer
        end

        require 'action_dispatch/routing/redirection'
        ActionDispatch::Routing::Redirect.class_eval do
          prepend XHRRedirect
        end
      end

      ActiveSupport.on_load(:action_view) do
        ActionView::Template.register_template_handler :kbuilder, Turbolinks::KbuilderHandler
        require 'turbolinks/dependency_tracker'
        require 'turbolinks/active_support'

        (ActionView::RoutingUrlFor rescue ActionView::Helpers::UrlHelper).module_eval do
          prepend XHRUrlFor
        end
      end
    end
  end
end
