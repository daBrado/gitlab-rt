require 'net/http'

class RTResponse
  LINE_SEP = /\n+([^ ]|$)/
  ARRAY_SEP = /^--$/
  KEY_VALUE_SEP = /(: |$)/
  COMMENT = /^#/
  LIST_SEP = /\s*,\s*/
  attr_reader :raw, :version, :code, :status, :comments, :body
  def initialize(body)
    @raw = body
    lines = body.split LINE_SEP
    lines = [*lines[0..0], *lines.drop(1).each_slice(2).map(&:join)]
    @version, @code, @status = lines.first.split(' ', 3)
    lines.shift
    @comments, lines = lines.partition{|line|COMMENT.match(line)}
    @body = lines.slice_before(ARRAY_SEP).map{|item|
      item.reject{|line|
        ARRAY_SEP.match line
      }.map{|line|
        line.split KEY_VALUE_SEP, 2
      }.map{|key,sep,value|
        value.gsub!("\n"+(' '*(key.size+sep.size)),"\n") if value.index("\n")
        [key, value]
      }.to_h
    }
  end
  def self.split_string(string); string.split LIST_SEP; end
  def self.join_array(array); array.join(', '); end
  def ok?; @code=="200"; end
  def no_credentials?; @code=="401"; end
end

class String
  def rt_split; RTResponse.split_string self; end
end
class Array
  def rt_join; RTResponse.join_array self; end
end

class RTClient
  class Error < RuntimeError; end
  class ConnectionError < Error; end
  class AuthenticationError < Error; end
  attr_accessor :cookie, :http
  def initialize(http:nil, path:nil, user:nil, pass:nil)
    @http = http
    @path = path
    @user = user
    @pass = pass
    @cookie = nil
  end
  def call(*path, format:nil, fields:nil, content:nil, user:nil, pass:nil, noauth:false)
    data = {}
    data.merge! format:format if format
    data.merge! fields:fields if fields
    data.merge!(user:user, pass:pass) if user && pass
    if content
      content = content.map{|k,v| [k, v.respond_to?(:join) ? v.join("\n ") : v]}.map{|k,v|"#{k}: #{v}\n"}.join if content.respond_to?(:map)
      data.merge! content:content
    end
    headers = @cookie ? {'Cookie'=>@cookie} : {}
    response = @http.post "#{@path}/REST/1.0/#{path.join('/')}", URI.encode_www_form(data), headers
    raise ConnectionError.new if response.code != "200"
    @cookie = response['set-cookie'].partition(';').first
    rtresponse = RTResponse.new response.body
    if rtresponse.no_credentials?
      raise AuthenticationError.new if noauth || !login
      rtresponse = call(*path, format:format, fields:fields, content:content, noauth:true)
    end
    raise Error.new(rtresponse.raw) if !rtresponse.ok?
    rtresponse
  end
  def login; call(user:@user, pass:@pass).ok?; end
end
