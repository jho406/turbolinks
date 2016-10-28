module Bensonhurst
  module XHRRedirect
    def call(env)
      status, headers, body = super(env)

      if env['rack.session'] && env['HTTP_X_XHR_REFERER']
        env['rack.session'][:_bensonhurst_redirect_to] = headers['Location']
      end

      [status, headers, body]
    end
  end
end
