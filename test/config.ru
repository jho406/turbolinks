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
  CHUNKS = [' '*50, ' '*20, 'Turbolinks.replace({"data":{"content":"Slow Reponse"},"turbolinks":{"assets":["/test.js","/test.css"]}});']

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

class MimeFile < Rack::File
  F = ::File

  def call(env)
    dup._call(env)
  end

  def _call(env)
    unless ALLOWED_VERBS.include? env["REQUEST_METHOD"]
      return fail(405, "Method Not Allowed", {'Allow' => ALLOW_HEADER})
    end

    path_info = Rack::Utils.unescape(env["PATH_INFO"])
    clean_path_info = Rack::Utils.clean_path_info(path_info)

    if F.extname(clean_path_info).empty?
      extname = case env['HTTP_ACCEPT']
      when /html/
        '.html'
      when /javascript/
        '.js'
      end

      clean_path_info += extname
    end

    @path = F.join(@root, clean_path_info)
    available = begin
      F.file?(@path) && F.readable?(@path)
    rescue SystemCallError
      false
    end

    if available
      serving(env)
    else
      fail(404, "File not found: #{path_info}")
    end
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
  run MimeFile.new(File.join(Root, "test", "javascript"))
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

    [200, { "Content-Type" => type }, File.open( File.join( Root, "test", filename ) ) ] }
end

map "/reload" do
  run Proc.new{|request|
    filename, type = if request['HTTP_ACCEPT'].include? 'javascript'
      ['reload.js', 'application/javascript']
    else
      ['reload.html', 'text/html']
    end

    [200, { "Content-Type" => type }, File.open( File.join( Root, "test", filename ) ) ] }
end

map "/attachment.txt" do
  run Proc.new{ [200, { "Content-Type" => "text/plain" }, File.open( File.join( Root, "test", "attachment.html" ) ) ] }
end

map "/attachment" do
  run Proc.new{ [200, { "Content-Type" => "text/html", "Content-Disposition" => "attachment; filename=attachment.html" }, File.open( File.join( Root, "test", "attachment.html" ) ) ] }
end

run Rack::Directory.new(File.join(Root, "test"))
