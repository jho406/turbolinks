require 'bensonhurst/version'
require 'bensonhurst/xhr_headers'
require 'bensonhurst/xhr_redirect'
require 'bensonhurst/xhr_url_for'
require 'bensonhurst/cookies'
require 'bensonhurst/x_domain_blocker'
require 'bensonhurst/render'
require 'bensonhurst/helpers'
require 'bensonhurst/configuration'
require 'bensonhurst/plum_template'
require 'bensonhurst/digestor'

module Bensonhurst
  module Controller
    include XHRHeaders, Cookies, XDomainBlocker, Render, Helpers

    def self.included(base)
      if base.respond_to?(:before_action)
        base.before_action :set_xhr_redirected_to, :set_request_method_cookie
        base.after_action :abort_xdomain_redirect
      else
        base.before_filter :set_xhr_redirected_to, :set_request_method_cookie
        base.after_filter :abort_xdomain_redirect
      end

      if base.respond_to?(:helper_method)
        base.helper_method :bensonhurst_tag
        base.helper_method :bensonhurst_silient?
        base.helper_method :bensonhurst_snippet
        base.helper_method :use_bensonhurst_html
      end
    end
  end

  class Engine < ::Rails::Engine
    config.bensonhurst = ActiveSupport::OrderedOptions.new
    config.bensonhurst.auto_include = true

    initializer :bensonhurst do |app|
      ActiveSupport.on_load(:action_controller) do
        next if self != ActionController::Base

        if app.config.bensonhurst.auto_include
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
        ActionView::Template.register_template_handler :plum, Bensonhurst::KbuilderHandler
        require 'bensonhurst/dependency_tracker'
        require 'bensonhurst/active_support'

        (ActionView::RoutingUrlFor rescue ActionView::Helpers::UrlHelper).module_eval do
          prepend XHRUrlFor
        end
      end
    end
  end
end
