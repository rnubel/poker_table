# Poker Table

<pre>
  table = PokerTable.new ante: 5,
                         deck: "2C 3C 2S 4C 2H 5C 2D 8C 9C 10C 4S 5S 6S 8S",
                         players: [
                          { id: "Robert", stack: 15},
                          { id: "Person", stack: 15}
                         ]

  table.simulate! [
    { player_id: "Robert", action: "bet", amount: 6 }
    { player_id: "Person", action: "bet", amount: 6 }
  ]

  table.pot # => 12
  table.round == 'draw'
  table.current_player[:id] == "Robert"

  table.valid_action?(player_id: "Person", action: "bet", amount: 6) # => false
  table.valid_action?(player_id: "Robert", action: "replace", cards: ["9C"]) # => true
</pre>


