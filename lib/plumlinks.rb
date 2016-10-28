require 'plumlinks/version'
require 'plumlinks/xhr_headers'
require 'plumlinks/xhr_redirect'
require 'plumlinks/xhr_url_for'
require 'plumlinks/cookies'
require 'plumlinks/x_domain_blocker'
require 'plumlinks/render'
require 'plumlinks/helpers'
require 'plumlinks/configuration'
require 'plumlinks/plum_template'
require 'plumlinks/digestor'

module Plumlinks
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
        base.helper_method :plumlinks_tag
        base.helper_method :plumlinks_silient?
        base.helper_method :plumlinks_snippet
        base.helper_method :use_plumlinks_html
      end
    end
  end

  class Engine < ::Rails::Engine
    config.plumlinks = ActiveSupport::OrderedOptions.new
    config.plumlinks.auto_include = true

    initializer :plumlinks do |app|
      ActiveSupport.on_load(:action_controller) do
        next if self != ActionController::Base

        if app.config.plumlinks.auto_include
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
        ActionView::Template.register_template_handler :plum, Plumlinks::KbuilderHandler
        require 'plumlinks/dependency_tracker'
        require 'plumlinks/active_support'

        (ActionView::RoutingUrlFor rescue ActionView::Helpers::UrlHelper).module_eval do
          prepend XHRUrlFor
        end
      end
    end
  end
end
