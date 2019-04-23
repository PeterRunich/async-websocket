#!/usr/bin/env ruby

require 'async'
require 'async/io/stream'
require 'async/http/url_endpoint'
require 'async/websocket/client'

USER = ARGV.pop || "anonymous"
URL = ARGV.pop || "ws://localhost:9292"

Async do |task|
	stdin = Async::IO::Stream.new(
		Async::IO::Generic.new($stdin)
	)
	
	endpoint = Async::HTTP::URLEndpoint.parse(URL)
	
	endpoint.connect do |socket|
		connection = Async::WebSocket::Client.new(socket, URL)
		
		connection.send_message({
			user: USER,
			status: "connected",
		})
		
		task.async do
			while line = stdin.read_until("\n")
				connection.send_message({
					user: USER,
					text: line,
				})
			end
		end
		
		while message = connection.next_message
			puts ": #{message.inspect}"
		end
	end
end
