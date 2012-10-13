require File.expand_path("../lib/poker_table/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name = 'poker_table'
  gem.version = PokerTable::VERSION
  gem.date = Date.today.to_s

  gem.summary = 'Play out a hand of poker... in memory!'

  gem.authors = ['Robert Nubel']
  gem.email = ['rnubel@enova.com']
  gem.homepage= 'http://git.cashnetusa.com/rnubel/poker_table'

  gem.add_dependency 'ruby-poker'

  gem.files = Dir['README*', '{lib,spec}/**/*']
end
