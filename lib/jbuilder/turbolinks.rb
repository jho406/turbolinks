require 'jbuilder/jbuilder_template'

class JbuilderTemplateWithTurbolinks < JbuilderTemplate
  alias_method :jbuilder_target!, :target!

  def initialize(context, turbolinks=nil)
    super(context)
    @turbolinks = turbolinks
  end

  def empty!
    attributes = @attributes
    @attributes = {}
    attributes
  end

  def target!
    return jbuilder_target! unless @turbolinks
    "Turbolinks.replace(#{jbuilder_target!});"
  end
end


class JbuilderHandler
  def self.call(template)
    # this juggling is required to keep line numbers right in the error
    %{__already_defined = defined?(json); json||=JbuilderTemplateWithTurbolinks.new(self, turbolinks);#{template.source}
      if turbolinks
        json.merge!({data: json.empty!})
        json.turbolinks do
          turbolinks.each do |k, v|
            json.set! k, v
          end

          if protect_against_forgery?
            json.csrf_token form_authenticity_token
          end
          
          if ::Turbolinks.configuration.track_assets.any?
            json.assets do
              json.array! (::Turbolinks.configuration.track_assets || []).map{|assets|
                asset_path(assets)
              }
            end
          end
        end
      end
      json.target! unless (__already_defined && __already_defined != "method")}
  end
end
