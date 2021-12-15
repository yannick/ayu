module Ayu

  #Resource, currently non stackable
  class Resource
    HTTPMethods = %i(get post put delete head options trace connect).uniq

    class << self
      def http_methods
        @http_methods ||= Array.new
      end
    end

    HTTPMethods.each do |http_method|
      define_singleton_method(http_method) do |&blk|
        bmname = :"__#{http_method}"
        define_method(bmname, &blk)
        define_method(http_method) do |*args|
          response = send(bmname, *args)
          case response
          when Array
            response
          else
            response = response.to_s
            [200, {'Content-Type' => 'text/plain'}, [response]] #TODO: check if h2o adds Content-Length
          end
        end
      end
      define_method(http_method) { |*args| default_http_method(*args) }
    end

    # Every resource, on being instantiated, is given the Rack env.
    def initialize(env, app = nil, params = nil)
      @env, @app, @params, @request = env, app, params, env["rack.input"]
    end

    #bounce back to h2o
    def default_http_method(*args)
      [399,{},[]]
    end

  end

  class App

    attr_accessor :app, :env, :params, :request

    Errors = {
      400 => [400, {'Content-Type' => 'text/plain'}, ["400 Bad Request.\n"]],
      404 => [404, {'Content-Type' => 'text/plain'}, ["404 Not Found\n"]],
      501 => [501, {'Content-Type' => 'text/plain'},["501 Not Implemented.\n"]],
      399 => [399,{}, []], #bounce to h2o
    }

    Routes = R3::Tree.new(100)

    # Method name cache.  Maps HTTP methods to object methods.
    # ~20% faster than .downcase.to_sym
    HttpMethods = Hash.new { |h,k| h[k] = k.downcase.to_sym }
    # Prefill HttpMethods above with the likely culprits:
    %w(GET PUT POST DELETE OPTIONS HEAD TRACE CONNECT PATCH).each{ |m| HttpMethods[m] }

    def self.resource(path, res = nil, &blk)
      Routes.add(path, R3::ANY, res)
    end

    def initialize
      Routes.compile
    end

    # Rack handler
    # TODO: define behaviour if method is not defined or no handler is found.
    # either bounce back to h2o or return an item from Errors
    def call env, req_path = nil
      rm = HttpMethods[env['REQUEST_METHOD']]
      return(Errors[501]) unless rm

      params, handler = Routes.match env['PATH_INFO']
      return Errors[399] unless handler

      resource = handler.new(env, self, params)
      response = resource.send(rm)
    end
  end

end
