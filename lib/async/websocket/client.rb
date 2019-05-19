# frozen_string_literals: true
#
# Copyright, 2015, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'request'

require 'async/http/middleware'
require 'async/http/body'

module Async
	module WebSocket
		PROTOCOL = "websocket".freeze
		
		# This is a basic synchronous websocket client:
		class Client < HTTP::Middleware
			def self.open(*args, &block)
				client = self.new(HTTP::Client.new(*args))
				
				return client unless block_given?
				
				begin
					yield client
				ensure
					client.close
				end
			end
			
			def make_connection(stream, headers)
				protocol = headers['sec-websocket-protocol']&.first
				
				
				framer = Protocol::WebSocket::Framer.new(stream)
				
				return Connection.new(framer, protocol)
			end
			
			def connect(path, headers = [])
				request = Request.new(nil, nil, path, headers)
				
				response = self.call(request)
				
				unless Array(response.protocol).include?(PROTOCOL)
					raise ProtocolError, "Unsupported protocol: #{response.protocol}"
				end
				
				if response.hijack?
					connection = make_connection(response.hijack!, response.headers)
				else
					stream = Async::HTTP::Body::Stream.new(response.body, request.body)
					connection = make_connection(stream, response.headers)
				end
				
				return connection unless block_given?
				
				begin
					yield connection
				ensure
					connection.close
				end
			end
		end
	end
end
