# frozen_string_literal: true

require "rack"

module HubStep
  module Rack
    # Rack middleware for wrapping a request in a span.
    class Middleware
      def initialize(app, tracer, enabled_proc)
        @app = app
        @tracer = tracer
        @enabled_proc = enabled_proc
      end

      def call(env)
        @tracer.with_enabled(@enabled_proc.call(env)) do
          trace(env) do
            @app.call(env)
          end
        end
      end

      private

      def trace(env)
        @tracer.span("Rack #{env["REQUEST_METHOD"]}") do |span|
          span.configure do
            add_tags(span, ::Rack::Request.new(env))
          end

          result = yield

          span.set_tag("http.status_code", result[0].to_s)

          result
        end
      end

      def add_tags(span, request)
        tags(request).each do |key, value|
          span.set_tag(key, value)
        end
      end

      def tags(request)
        tags = {
          "component" => "rack",
          "span.kind" => "server",
          "http.url" => request.url,
          "http.method" => request.request_method,
        }
        id = request_id(request)
        if id
          tags["guid:github_request_id"] = id
        end

        tags.freeze
      end

      def request_id(request)
        request.env["HTTP_X_GITHUB_REQUEST_ID"]
      end
    end
  end
end