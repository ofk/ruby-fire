# frozen_string_literal: true

require 'ruby-fire'

def hello(name = 'World')
  "Hello #{name}!"
end

Fire.fire(:hello) if __FILE__ == $0
