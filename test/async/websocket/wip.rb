# frozen_string_literal: true

require 'async/websocket/client'
require 'sus/fixtures/async/http/server_context'

=begin
#close arguments work :)


on server

rescue Errno::EPIPE => e
changed to
rescue Protocol::WebSocket::ClosedError => e

i think it's good

further read "with" descriptions
i read a little more about error codes
https://www.rfc-editor.org/rfc/rfc6455.html#section-5.1 about 1002, maybe this relates to the second test case
i started using 4000-4999 range codes, just in case, because the interpretation of these codes is undefined by this protocol
=end

ClientExamples = Sus::Shared("a websocket client") do
	let(:timeout) { nil }


	with "http1 is ok, http2 test stacks as before" do
		let(:close_condition) { Async::Condition.new }

		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Async::WebSocket::Adapters::HTTP.open(request) do |connection|
					while connection.read; end
				rescue Protocol::WebSocket::ClosedError => e
					connection.close

					close_condition.signal e.code
				end
			end
		end

		let(:timeout) { nil }

		it "closes with custom error" do
			expectation = Async { expect(close_condition.wait).to be == 4000 }

			connection = Async::WebSocket::Client.connect(client_endpoint)
			connection.close 4000

			expectation.wait
		end
	end

	with("http1 Async::TimeoutError: execution expired and client rcv 1002, http2 Protocol::HTTP2::ProtocolError: Cannot send data in state: closed") do
		let(:close_condition) { Async::Condition.new }

		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Async::WebSocket::Adapters::HTTP.open(request) do |connection|
					while connection.read; end
				rescue Protocol::WebSocket::ClosedError => e
					connection.close 4000

					close_condition.signal e.code
				end
			end
		end

		let(:timeout) { nil }

		it "closes with custom error" do
			expectation = Async { expect(close_condition.wait).to be == 4000 }
			connection = Async::WebSocket::Client.connect(client_endpoint)

			Async do
				while connection.read; end
			rescue Protocol::WebSocket::ClosedError => e
				p e.code
			end

			sleep 1 # if comment this, test passes with http1, http2 EOFError: Could not read frame header! 💀💀💀

			connection.close 4000

			expectation.wait
		end
	end
end

describe Async::WebSocket::Client do
	include Sus::Fixtures::Async::HTTP::ServerContext

	with 'http/1' do
		let(:protocol) {Async::HTTP::Protocol::HTTP1}
		it_behaves_like ClientExamples
	end

	with 'http/2' do
		let(:protocol) {Async::HTTP::Protocol::HTTP2}
		it_behaves_like ClientExamples
	end
end
