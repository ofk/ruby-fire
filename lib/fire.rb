# frozen_string_literal: true

require 'fire/version'
require 'xoptparse'
require 'pp'

class Fire
  METHODS_CODE = 'public_methods(false)+private_methods(false)'
  TOPLEVEL_METHODS = TOPLEVEL_BINDING.eval(METHODS_CODE)

  class << self
    def fire(*args, **kwargs, &block)
      res = new(*args, **kwargs, &block).run
      puts res.is_a?(String) ? res : res.pretty_inspect unless res.nil?
    end

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

    def new_method?(func)
      func.is_a?(Method) && func.owner.is_a?(Class) && func.name == :new
    end

    def trace_parameters(trace_func) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      is_proc = trace_func.is_a?(Proc)
      func = new_method?(trace_func) ? trace_func.receiver.instance_method(:initialize) : trace_func

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

  def initialize(rec = nil, program_name: nil, &block)
    if rec.is_a?(Symbol)
      main = TOPLEVEL_BINDING.receiver
      rec = (main.method(rec) if main.private_methods.include?(rec) || main.methods.include?(rec))
    end
    @rec = rec || block || proc {}
    @program_name = program_name
  end

  def parser
    XOptionParser.new do |opt|
      opt.program_name = @program_name if @program_name
      @current_run_params = define_method_options(opt, @rec)
    end
  end

  def define_method_options(opt, func) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    convert_classes = [].tap do |a|
      opt.send(:visit, :tap) do |el|
        el.atype.each do |key, _val|
          a << key if key.is_a?(Class) && ![Object, NilClass].include?(key)
        end
      end
    end

    func_parameters = self.class.trace_parameters(func)
    if func_parameters.any? { |type, *_args| %i[req opt rest keyreq key].include?(type) }
      opt.separator ''
      opt.separator 'Options:'
    end
    func_parameters.each do |type, name, default|
      conv_class = convert_classes.find { |kl| default.is_a?(kl) }
      klass = conv_class || Object
      desc = %i[opt key].include?(type) ? "(default #{default})" : ''
      case type
      when :req
        opt.on(name.to_s, klass, desc, &:itself)
      when :opt
        opt.on("[#{name}]", klass, desc, &:itself)
      when :rest
        opt.on("[#{name}...]", klass, desc, &:itself)
      when :keyreq, :key
        long = if [TrueClass, FalseClass].include?(conv_class)
                 "--[no-]#{name} [FLAG]"
               else
                 "--#{name} #{(conv_class || String).to_s.upcase}"
               end
        opt.on(long, klass, desc, &:itself)
      end
    end

    [func, func_parameters]
  end
  private :define_method_options

  def parse!(argv = ARGV)
    @opt = parser
    @params = {}
    @opt.parse!(argv, into: @params)
  end

  def run!(*args)
    parse!(*args)
    func, func_parameters = @current_run_params
    self.class.parameters_call(func, func_parameters, @params)
  end

  def run(*args)
    run!(*args)
  rescue XOptionParser::ParseError
    puts @opt.help
    exit
  end

  class TracePointTerminate < StandardError
  end
end
