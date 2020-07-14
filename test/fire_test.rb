# frozen_string_literal: true

require 'test_helper'

def mock_noop
  0
end

alias mock_noop2 mock_noop

def mock_simple(a, b = 1, c = 2)
  [a, b, c]
end

alias mock_simple2 mock_simple

def mock_method(a, b, m = 1, n = mock_noop, *rest, x, y, z:, w:, k: 1, l: mock_noop2, **kwrest, &blk)
  blk&.call
  [a, b, m, n, rest, x, y, z, w, k, l, kwrest]
end

define_method(:mock_define_method) { |a, b, m = 1, n = mock_noop, *rest, x, y, z:, w:, k: 1, l: mock_noop2, **kwrest, &blk| }

def mock_method2(a, b = 1, *rest, x:, y: 1, z: false)
  [a, b, rest, x, y, z]
end

class MockClass
  def self.static_method(a, b, m = 1, n = mock_noop, *rest, x, y, z:, w:, k: 1, l: mock_noop2, **kwrest, &blk); end

  def initialize(a, b, m = 1, n = mock_noop, *rest, x, y, z:, w:, k: 1, l: mock_noop2, **kwrest, &blk); end

  def method(a, b, m = 1, n = mock_noop, *rest, x, y, z:, w:, k: 1, l: mock_noop2, **kwrest, &blk); end
end

class MockClass2
  def self.f(a = 1)
    a
  end

  def initialize(b)
    @b = b
  end

  def g(c)
    [@b, c]
  end
end

class FireTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute { ::Fire::VERSION.nil? }
  end

  def test_trace_parameters
    mock_lambda = ->(a, b, m = 1, n = mock_noop, *rest, x, y, z:, w:, k: 1, l: mock_noop2, **kwrest, &blk) {}
    mock_proc = proc { |a, b, m = 1, n = mock_noop, *rest, x, y, z:, w:, k: 1, l: mock_noop2, **kwrest, &blk| }
    mock_proc2 = proc { 2 }
    mock_proc3 = proc { |a, b = 1, c = mock_proc2.call| }

    assert { Fire.trace_parameters(method(:mock_noop)) == [] }
    assert { Fire.trace_parameters(method(:mock_noop2)) == [] }

    assert { Fire.trace_parameters(method(:mock_simple)) == [[:req, :a, nil], [:opt, :b, 1], [:opt, :c, 2]] }
    assert { Fire.trace_parameters(method(:mock_simple2)) == [[:req, :a, nil], [:opt, :b, 1], [:opt, :c, 2]] }

    assert { Fire.trace_parameters(method(:mock_method)) == [[:req, :a, nil], [:req, :b, nil], [:opt, :m, 1], [:opt, :n, 0], [:rest, :rest, nil], [:req, :x, nil], [:req, :y, nil], [:keyreq, :z, nil], [:keyreq, :w, nil], [:key, :k, 1], [:key, :l, 0], [:keyrest, :kwrest, nil], [:block, :blk, nil]] }
    assert { Fire.trace_parameters(method(:mock_define_method)) == [[:req, :a, nil], [:req, :b, nil], [:opt, :m, nil], [:opt, :n, nil], [:rest, :rest, nil], [:req, :x, nil], [:req, :y, nil], [:keyreq, :z, nil], [:keyreq, :w, nil], [:key, :k, 1], [:key, :l, nil], [:keyrest, :kwrest, nil], [:block, :blk, nil]] } # mock_define_method cannot take initial values

    assert { Fire.trace_parameters(mock_lambda) == [[:req, :a, nil], [:req, :b, nil], [:opt, :m, 1], [:opt, :n, 0], [:rest, :rest, nil], [:req, :x, nil], [:req, :y, nil], [:keyreq, :z, nil], [:keyreq, :w, nil], [:key, :k, 1], [:key, :l, 0], [:keyrest, :kwrest, nil], [:block, :blk, nil]] }
    assert { Fire.trace_parameters(mock_proc) == [[:opt, :a, nil], [:opt, :b, nil], [:opt, :m, 1], [:opt, :n, 0], [:rest, :rest, nil], [:opt, :x, nil], [:opt, :y, nil], [:keyreq, :z, nil], [:keyreq, :w, nil], [:key, :k, 1], [:key, :l, 0], [:keyrest, :kwrest, nil], [:block, :blk, nil]] } # proc does not return req

    assert { Fire.trace_parameters(mock_proc3) == [[:opt, :a, nil], [:opt, :b, 1], [:opt, :c, 2]] }

    assert { Fire.trace_parameters(MockClass.method(:static_method)) == [[:req, :a, nil], [:req, :b, nil], [:opt, :m, 1], [:opt, :n, 0], [:rest, :rest, nil], [:req, :x, nil], [:req, :y, nil], [:keyreq, :z, nil], [:keyreq, :w, nil], [:key, :k, 1], [:key, :l, 0], [:keyrest, :kwrest, nil], [:block, :blk, nil]] }
    assert { Fire.trace_parameters(MockClass.method(:new)) == [[:req, :a, nil], [:req, :b, nil], [:opt, :m, 1], [:opt, :n, 0], [:rest, :rest, nil], [:req, :x, nil], [:req, :y, nil], [:keyreq, :z, nil], [:keyreq, :w, nil], [:key, :k, 1], [:key, :l, 0], [:keyrest, :kwrest, nil], [:block, :blk, nil]] }

    assert { Fire.trace_parameters(File.method(:symlink)) == [[:req, nil, nil], [:req, nil, nil]] }
    assert { Fire.trace_parameters(File.method(:utime)) == [[:rest, nil, nil]] }
  end

  def test_parameters_call
    f1 = method(:mock_simple)
    f1p = Fire.trace_parameters(f1)
    assert { Fire.parameters_call(f1, f1p, { a: 10, b: 20, c: 30 }) == [10, 20, 30] }
    assert { Fire.parameters_call(f1, f1p, { a: 10, c: 30 }) == [10, 1, 30] }
    assert { Fire.parameters_call(f1, f1p, { a: 10 }) == [10, 1, 2] }
    assert_raises(ArgumentError) { Fire.parameters_call(f1, f1p, { a: 10, b: 20, c: 30, d: 40 }) }
    assert_raises(ArgumentError) { Fire.parameters_call(f1, f1p, {}) }

    f2 = method(:mock_method)
    f2p = Fire.trace_parameters(f2)
    assert { Fire.parameters_call(f2, f2p, { a: 1, b: 2, m: 3, n: 4, rest: [5, 6], x: 7, y: 8, z: 9, w: 10, k: 11, l: 12, d: 13, e: 14 }) == [1, 2, 3, 4, [5, 6], 7, 8, 9, 10, 11, 12, { d: 13, e: 14 }] }
    assert { Fire.parameters_call(f2, f2p, { a: 1, b: 2, x: 7, y: 8, z: 9, w: 10 }) == [1, 2, 1, 0, [], 7, 8, 9, 10, 1, 0, {}] }

    f3 = MockClass2.method(:f)
    f3p = Fire.trace_parameters(f3)
    assert { Fire.parameters_call(f3, f3p, { a: 0 }).zero? }

    f4 = MockClass2.method(:new)
    f4p = Fire.trace_parameters(f4)
    assert { Fire.parameters_call(f4, f4p, { b: 1 }).is_a?(MockClass2) }

    f5 = MockClass2.new(1).method(:g)
    f5p = Fire.trace_parameters(f5)
    assert { Fire.parameters_call(f5, f5p, { c: 2 }) == [1, 2] }
  end

  def test_run_method
    assert { Fire.new(:mock_simple, program_name: 'test').parser.help == "Usage: test a [b] [c]\n\nOptions:\n    a\n    [b]                              (default 1)\n    [c]                              (default 2)\n" }
    assert_raises(XOptionParser::MissingArgument) { Fire.new(:mock_simple).run!([]) }
    assert_raises(XOptionParser::InvalidOption) { Fire.new(:mock_simple).run!(%w[1 -d 4]) }
    assert { Fire.new(:mock_simple).run(%w[1 2 3]) == ['1', 2, 3] }
    assert { Fire.new(:mock_simple).run(%w[1 -c 3]) == ['1', 1, 3] }
    assert { Fire.new(:mock_simple).run(%w[-a 0]) == ['0', 1, 2] }

    assert { Fire.new(:mock_method2, program_name: 'test').parser.help == "Usage: test [options] a [b] [rest...]\n\nOptions:\n    a\n    [b]                              (default 1)\n    [rest...]\n        --x STRING\n        --y INTEGER                  (default 1)\n        --[no-]z [FLAG]              (default false)\n" }
    assert { Fire.new(:mock_method2).run(%w[--x 1 --y 2 3 4 5 6]) == ['3', 4, %w[5 6], '1', 2, false] }
    assert { Fire.new(:mock_method2).run(%w[--z yes --y 1 --x 2 1 2]) == ['1', 2, [], '2', 1, true] }
    assert { Fire.new(:mock_method2).run(%w[--z no --x 1 2]) == ['2', 1, [], '1', 1, false] }
  end
end
