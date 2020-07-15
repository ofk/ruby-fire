# frozen_string_literal: true

require 'ruby-fire'

class Calculator
  def double(number)
    2 * number.to_i
  end
end

Fire.fire(Calculator) if __FILE__ == $0
