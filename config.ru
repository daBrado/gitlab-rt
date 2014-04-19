#!/usr/bin/ruby

require 'rubygems'
require 'bundler/setup'
require 'json'
require 'logger'
require_relative 'rtclient'
require_relative 'config'

class GitLabRT
  TICKET_REGEXP = /#([0-9]+)/
  LINKTYPE = 'ReferredToBy'
  def initialize(rt, log:Logger.new(STDERR))
    @rt = rt
    @log = log
    @mutex = Mutex.new
  end
  def update_links(ticket, type)
    @mutex.synchronize do
      current_links = @rt.call('ticket', ticket, 'links', format:'l').body.first[type].rt_split.sort
      links = yield current_links
      ((current_links|links)-(current_links&links)).size.times do
        @rt.call 'ticket', ticket, 'links', content:{type=>links.rt_join}
        @log.info "Sent an update to RT"
      end
    end
  end
  def call(env)
    req = Rack::Request.new env
    begin
      push = JSON.parse body=req.body.read
    rescue JSON::ParserError
      @log.error "Cannot parse request #{body}"
      return [400, {}, []]
    end
    push['commits'].each do |commit|
      url = commit['url']
      commit['message'].scan(TICKET_REGEXP).flatten.each do |ticket|
        update_links(ticket, LINKTYPE){|links| links + [url]}
        @log.info "Updated #{LINKTYPE} links for ticket #{ticket} to include #{url}"
      end
    end
    [200, {}, []]
  end
end

http, path = RTClient.make_http_and_path RTURI, RTCERT
rt = RTClient.new http:http, path:path, user:RTUSER, pass:RTPASS
if !rt.login; STDERR.puts "login failure"; exit 1; end
run GitLabRT.new rt
