#!/usr/bin/ruby

require 'rubygems'
require 'bundler/setup'
require 'json'
require 'logger'
require 'openssl'
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

rturi = URI.parse RTURI
http = Net::HTTP.new rturi.host, rturi.port
if rturi.is_a? URI::HTTPS
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  http.ca_file = RTCERT if RTCERT
end
rt = RTClient.new http:http, path:rturi.path
rt.login RTUSER, RTPASS
run GitLabRT.new rt
