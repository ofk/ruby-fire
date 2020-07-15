# frozen_string_literal: true

require 'ruby-fire'

def caesar_encode(n = 0, text = '')
  text.chars.map { |char| _caesar_shift_char(n, char) } * ''
end

def caesar_decode(n = 0, text = '')
  caesar_encode(-n, text)
end

def rot13(text)
  caesar_encode(13, text)
end

def _caesar_shift_char(n = 0, char = ' ')
  return char unless /^[A-Za-z]$/ =~ char
  return ((char.ord - 'A'.ord + n) % 26 + 'A'.ord).chr if /^[A-Z]$/ =~ char

  ((char.ord - 'a'.ord + n) % 26 + 'a'.ord).chr
end

# puts rot13('Hello world!') == 'Uryyb jbeyq!'
# puts rot13('Uryyb jbeyq!') == 'Hello world!'
# puts caesar_encode(1, 'Hello world!') == 'Ifmmp xpsme!'
# puts caesar_decode(1, 'Ifmmp xpsme!') == 'Hello world!'

Fire.fire(program_name: 'cipher') if __FILE__ == $0
