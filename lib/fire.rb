# frozen_string_literal: true

require 'fire/version'

class Fire
  class << self
    def parameters_call(func, func_parameters, params, error = true)
      args, kwargs = method_arguments(func_parameters, params)
      raise ArgumentError, "unknown keywords: #{params.keys.join(', ')}" if error && !params.empty?

      if kwargs
        func.call(*args, **kwargs)
      else
        func.call(*args)
      end
    end

    def method_arguments(func_parameters, params) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      args = []
      kwargs = nil
      skip_opts = []
      func_parameters.each do |type, name, default|
        case type
        when :req
          args << params.delete(name) if params.include?(name)
        when :opt
          if params.include?(name)
            args << skip_opts.shift until skip_opts.empty?
            args << params.delete(name)
          else
            skip_opts << default
          end
        when :rest
          args.push(*(params.delete(name) || []))
        when :keyreq, :key
          (kwargs ||= {})[name] = params.delete(name) if params.include?(name)
        when :keyrest
          params.each_key do |key|
            (kwargs ||= {})[key] = params.delete(key)
          end
        end
      end
      [args, kwargs]
    end
    private :method_arguments

    def trace_parameters(trace_func) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      is_proc = trace_func.is_a?(Proc)
      is_init = !is_proc && trace_func.owner.is_a?(Class) && trace_func.name == :new
      func = is_init ? trace_func.receiver.instance_method(:initialize) : trace_func

      mock_kwargs = nil
      func.parameters.each do |type, name|
        (mock_kwargs ||= {})[name] = nil if type == :keyreq
      end
      mock_arg_size = (func.arity.negative? ? ~func.arity : func.arity) - (mock_kwargs ? 1 : 0)
      mock_args = Array.new(mock_arg_size)

      [].tap do |results|
        counts = { call: 0, b_call: -1, c_call: -1 }
        trace = TracePoint.new(:call, :b_call, :c_call) do |tp|
          # :nocov:
          count = counts[tp.event] += 1
          next unless count.positive?

          if is_proc
            next unless tp.event == :b_call

            # It is difficult to skip extra block...
            vars = tp.binding.local_variables
            next unless func.parameters.all? { |_type, name| vars.include?(name) }
          else
            next if tp.event == :b_call
            next unless tp.defined_class == func.owner && tp.callee_id == func.name
          end

          func.parameters.each do |type, name|
            opt = %i[opt key].include?(type)
            results << [type, name, opt && name ? tp.binding.local_variable_get(name) : nil]
          end
          raise TracePointTerminate
          # :nocov:
        end
        trace.enable do
          if mock_kwargs
            trace_func.call(*mock_args, **mock_kwargs)
          else
            trace_func.call(*mock_args)
          end
        end
      rescue TracePointTerminate # rubocop:disable Lint/SuppressedException
      end
    end
  end

  class TracePointTerminate < StandardError
  end
end
