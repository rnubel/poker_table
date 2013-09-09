require_relative '../lib/poker_table'
require_relative '../lib/draw_poker_table'
require_relative '../lib/hold_em_poker_table'

require 'pry'

RSpec.configure do |c|
  c.mock_with :mocha
end
