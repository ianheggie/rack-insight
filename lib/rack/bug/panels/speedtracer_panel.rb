require 'rack/bug'
begin
  require 'yajl'
rescue LoadError
  #Means no Chrome Speedtracer...
end
require 'uuid'

require 'rack/bug/panels/speedtracer_panel/trace-app'
require 'rack/bug/panels/speedtracer_panel/tracer'

class Rack::Bug
  class SpeedTracerPanel < Panel
    class Middleware
      def initialize(app)
        @app = app
        @uuid = UUID.new
      end

      def database
        SpeedTracerPanel.database
      end

      def call(env)
        if %r{^/__rack_bug__/} =~ env["REQUEST_URI"] 
          @app.call(env)
        else
          env['st.id'] = @uuid.generate

          tracer = SpeedTrace::Tracer.new(env['st.id'], 
                                          env['REQUEST_METHOD'], 
                                          env['REQUEST_URI'])
          env['st.tracer'] = tracer
          Thread::current['st.tracer'] = tracer

          status, headers, body = @app.call(env)

          env['st.tracer'].finish
          database[env['st.id']] = env['st.tracer']
          headers['X-TraceUrl'] = '/speedtracer?id=' + env['st.id']
          return [status, headers, body]
        end
      end
    end

    def self.database
      @db ||= {}
    end

    def database
      self.class.database
    end

    def initialize(app)
      @app  = app
      super
    end

    def panel_app
      return SpeedTrace::TraceApp.new(database)
    end

    def name
      "speedtracer"
    end

    def heading
      "#{database.keys.length} traces"
    end

    def content
      traces = database.to_a.sort do |one, two|
        two[1].start <=> one[1].start
      end
      advice = []
      if not defined?(Yajl)
        advice << "yajl-ruby not installed - Speedtracer server events won't be available"
      end
      render_template "panels/speedtracer/traces", :traces => traces, :advice => advice
    end

    def before(env)
    end

    def after(env, status, headers, body)
    end
  end
end

require 'rack/bug/panels/speedtracer_panel/instrument'
