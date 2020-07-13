# frozen_string_literal: true

require 'test_helper'

def mock_noop
  0
end

alias mock_noop2 mock_noop

def mock_simple(a, b = 1, c = 2); end

alias mock_simple2 mock_simple

def mock_method(a, b, m = 1, n = mock_noop, *rest, x, y, z:, w:, k: 1, l: mock_noop2, **kwrest, &blk); end

define_method(:mock_define_method) { |a, b, m = 1, n = mock_noop, *rest, x, y, z:, w:, k: 1, l: mock_noop2, **kwrest, &blk| }

class MockClass
  def self.static_method(a, b, m = 1, n = mock_noop, *rest, x, y, z:, w:, k: 1, l: mock_noop2, **kwrest, &blk); end

  def initialize(a, b, m = 1, n = mock_noop, *rest, x, y, z:, w:, k: 1, l: mock_noop2, **kwrest, &blk); end

  def method(a, b, m = 1, n = mock_noop, *rest, x, y, z:, w:, k: 1, l: mock_noop2, **kwrest, &blk); end
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
end
