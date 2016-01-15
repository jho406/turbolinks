require 'sprockets'
require 'coffee-script'
require 'rack/utils'
require 'rack/mime'

Root = File.expand_path("../..", __FILE__)

Assets = Sprockets::Environment.new do |env|
  env.append_path File.join(Root, "lib", "assets", "javascripts")
  env.append_path File.join(Root, "node_modules", "mocha")
  env.append_path File.join(Root, "node_modules", "chai")
  env.append_path File.join(Root, "node_modules", "jquery", "dist")
  env.append_path File.join(Root, "test", "javascript")
end

class SlowResponse
  CHUNKS = [' '*50, ' '*20, 'Turbolinks.replace({"data":{"content":"Slow Reponse"},"assets":["/test.js","/test.css"]});']

  def call(env)
    [200, headers, self]
  end

  def each
    CHUNKS.each do |part|
      sleep rand(0.3..0.8)
      yield part
    end
  end

  def length
    CHUNKS.join.length
  end

  def headers
    { "Content-Length" => length.to_s, "Content-Type" => "application/javascript", "Cache-Control" => "no-cache, no-store, must-revalidate" }
  end
end


map "/js" do
  run Assets
end

map "/500" do
  # throw Internal Server Error (500)
  run Proc.new{
    raise
  }
end

map "/withoutextension" do
  run Rack::File.new(File.join(Root, "test", "withoutextension"), "Content-Type" => "text/html")
end

map "/javascript" do
  run Proc.new{|request|
    ext, type = if request['HTTP_ACCEPT'].include? 'javascript'
      ['js', 'application/javascript']
    else
      ['html', 'text/html']
    end

    path = File.join(Root, "test", "javascript", [request["PATH_INFO"].split('.')[0],ext].join('.'))

    available = begin
      File.file?(path) && File.readable?(path)
    rescue SystemCallError
      false
    end

    if available
      [200, { "Content-Type" => type }, File.open( path ) ]
    else
      fail(404, "File not found: #{path}")
    end
  }
end

map "/slow-response" do
  run SlowResponse.new
end

map "/bounce" do
  run Proc.new{ [200, { "X-XHR-Redirected-To" => "redirect1", "Content-Type" => "application/javascript" }, File.open( File.join( Root, "test", "redirect1.js" ) ) ] }
end

map "/other" do
  run Proc.new{|request|
    filename, type = if request['HTTP_ACCEPT'].include? 'javascript'
      ['other.js', 'application/javascript']
    else
      ['other.html', 'text/html']
    end

    [200, { "Content-Type" => type }, File.open( File.join( Root, "test", filename ) ) ]
  }
end

map "/reload" do
  run Proc.new{|request|
    filename, type = if request['HTTP_ACCEPT'].include? 'javascript'
      ['reload.js', 'application/javascript']
    else
      ['reload.html', 'text/html']
    end

    [200, { "Content-Type" => type }, File.open( File.join( Root, "test", filename ) ) ]
  }
end

map "/attachment.txt" do
  run Proc.new{ [200, { "Content-Type" => "text/plain" }, File.open( File.join( Root, "test", "attachment.html" ) ) ] }
end

map "/attachment" do
  run Proc.new{ [200, { "Content-Type" => "text/html", "Content-Disposition" => "attachment; filename=attachment.html" }, File.open( File.join( Root, "test", "attachment.html" ) ) ] }
end

run Rack::Directory.new(File.join(Root, "test"))
