require 'spec_helper'

describe HoldEmPokerTable do
  let(:deck){
    "5H AS 9C TH QH QS 2C 3C 4H AC JS JC KC 3H 3D 8S"
  }

  context "with two players" do
    let(:players) {
      [
         { id: "playerone",
           stack: 10 },
         { id: "playertwo",
           stack: 15 }
      ]
    }

    context "when first initialized" do
      let(:table) {
        HoldEmPokerTable.new deck: deck,
                       ante: 5,
                       players: players
      }

      it "should still be recognized as a PokerTable" do
        table.should be_a(PokerTable)
      end

      it "should split the deck into cards" do
        table.deck.should == deck.split(" ")
      end
    end

    context "when simulating play from a list of actions" do
      let(:table) {
        HoldEmPokerTable.new deck: deck,
                       big_blind: 6,
                       players: players
      }

      context "when given an empty list of actions" do
        before :each do
          table.simulate!([])
        end

        it "deals cards and takes blinds" do
          # first player gets big blind, second went first and got small
          table.players.first[:stack].should == 4
          table.players.first[:hand].should == ["5H","9C"]

          table.players.last[:stack].should == 12
          table.players.last[:hand].should == ["AS","TH"]
        end

        it "sets the round as 'deal'" do
          table.round.should == 'deal'
        end
      end

      context "when given a valid sequence of bets to end the first round" do
        before :each do
          table.simulate!([
            # one deals, two small blinds, one big blinds, two starts the betting round
            { player_id: "playertwo", action: "bet", amount: 1 },
            { player_id: "playerone", action: "bet", amount: 0 } 
          ])
        end

        it "shows the round as 'flop'" do
          table.round.should == 'flop'
        end

        it "gives the community a set of cards after discarding a card" do
          table.community_cards.should == ["QS", "2C", "3C"]
        end
      end

      context "when given a valid, more complex sequence of bets to end the first round" do
        before :each do
          table.simulate!([
            # one deals, two small blinds, one big blinds, two starts the betting round
            { player_id: "playertwo", action: "bet", amount: 1 },
            { player_id: "playerone", action: "bet", amount: 1 },
            { player_id: "playertwo", action: "bet", amount: 1 },
            { player_id: "playerone", action: "bet", amount: 0 }
          ])
        end

        it "still has two active players" do
          table.active_players.size.should == 2
        end

        it "shows the round as 'flop'" do
          table.round.should == 'flop'
        end

        it "gives the community a set of cards after discarding a card" do
          table.community_cards.should == ["QS", "2C", "3C"]
        end
      end

      context "when given valid actions to end the pre-flop betting and the post-flop betting" do
        before :each do
          table.simulate!([
            # player two places small blind, one places big, then two bets
            { player_id: "playertwo", action: "bet", amount: 1 },
            { player_id: "playerone", action: "bet", amount: 0 },
            { player_id: "playertwo", action: "bet", amount: 1 },
            { player_id: "playerone", action: "bet", amount: 0 }
          ])
        end

        it "shows the round as 'turn'" do
          table.round.should == 'turn'
        end

        it "burns and turns another card" do
          table.community_cards.should == ["QS", "2C", "3C", "AC"]
        end
      end

      context "when given valid actions to bet pre-flop, post-flop, and before the river" do
        before :each do
          table.simulate!([
            # one deals, two small blinds, one big blinds, two starts the betting round
            # deal
            { player_id: "playertwo", action: "bet", amount: 1 },
            { player_id: "playerone", action: "bet", amount: 0 },
            # flop
            { player_id: "playertwo", action: "bet", amount: 1 },
            { player_id: "playerone", action: "bet", amount: 0 },
            # turn
            { player_id: "playertwo", action: "bet", amount: 1 },
            { player_id: "playerone", action: "bet", amount: 0 }
          ])
        end

        it "burns and turns another card" do
          table.community_cards.should == ["QS", "2C", "3C", "AC", "JC"]
        end

        it "shows the round as 'river'" do
          table.round.should == 'river'
        end
      end

      context "when given valid actions to end a full hand" do
        before :each do
          table.simulate!([
            # one deals, two small blinds, one big blinds, two starts the betting round
            # draw
            { player_id: "playertwo", action: "bet", amount: 1 },
            { player_id: "playerone", action: "bet", amount: 0 },
            # flop
            { player_id: "playertwo", action: "bet", amount: 0 },
            { player_id: "playerone", action: "bet", amount: 0 },
            # turn
            { player_id: "playertwo", action: "bet", amount: 1 },
            { player_id: "playerone", action: "bet", amount: 0 },
            # river
            { player_id: "playertwo", action: "bet", amount: 1 },
            { player_id: "playerone", action: "bet", amount: 0 },
          ])
        end

        it "shows the round as being 'showdown'" do
          table.round.should == 'showdown'
        end

        it "knows the round's winners and their winnings" do
          # (6 + 1 + 1 + 1 = 9) * 2 = 18
          table.winners.should == [{ player_id: "playerone", winnings: 18 }]
        end

        it "lists total stack changes per player" do
          table.stack_changes.should == { "playertwo" => -9, "playerone" => 9 }
        end
      end

      context "when given invalid actions" do
        it "ignores invalid bets and wait for a valid bet" do
          table.simulate!([
              { player_id: "playertwo", action: "bet", amount: 1 },
              { player_id: "playerone", action: "bet", amount: -1 },
            ])

          table.current_player[:id].should == "playerone"
        end

        it "recognizes an invalid bet after simulating" do
          table.simulate!([
              { player_id: "playertwo", action: "bet", amount: 1 }
            ])

          table.valid_action?(
              { player_id: "playerone", action: "bet", amount: -1 }
          ).should be_false
        end

        it "recognizes when its not a players turn" do
          table.simulate!([
              { player_id: "playerone", action: "bet", amount: 1 }
            ])

          table.valid_action?(
              { player_id: "playerone", action: "bet", amount: 1 }
          ).should be_false
        end

        it "does not allow the replace action" do
          table.simulate!([
              { player_id: "playerone", action: "bet", amount: 1 },
              { player_id: "playertwo", action: "bet", amount: 0 }
            ])

         table.valid_action?(player_id: "playerone", action: "replace")
            .should be_false
        end
      end

      describe "folding" do
        it "allows the action 'fold" do
          table.simulate!([
              { player_id: "playerone", action: "bet", amount: 1 }
            ])

          table.valid_action?(player_id: "playertwo", action: "fold")
            .should be_true
        end

        it "ends the round if N-1 players fold with the Nth the winner" do
          table.simulate!([
              { player_id: "playertwo", action: "fold" }
            ])

          table.winners.first[:player_id].should == "playerone"
        end
      end

      describe "player rotation" do
        it "starts off at the player after the dealer" do
          table.simulate!([])
          table.current_player[:id].should == "playertwo"
        end

        it "rotates to the next player if that player folds" do
          table.simulate!([
              { player_id: "playertwo", action: "fold" }
            ])
          table.current_player[:id].should == "playerone"
        end

        it "does not blow up if both players say they fold" do
          table.simulate!([
              { player_id: "playertwo", action: "fold" },
              { player_id: "playerone", action: "fold" }
            ])
        end
      end
    end


    describe "#active_players" do
      it "excludes folded players" do
        t = HoldEmPokerTable.new
        t.expects(:players).returns([{:folded => true}, {}])
        t.active_players.should == [{}]
      end

      it "excludes kicked players" do
        t = HoldEmPokerTable.new
        t.expects(:players).returns([{:kicked => true}, {}])
        t.active_players.should == [{}]
      end
    end

    describe "#take_blinds!" do
      it "forces a player all in if they cannot meet the blind" do
        t = HoldEmPokerTable.new deck: deck,
                       big_blind: 12,
                       players: players
        t.simulate!

        t.active_players.size.should == 2
      end

      it "kicks a player out if they have zero chips" do
        t = HoldEmPokerTable.new deck: deck,
                       ante: 12,
                       players: [ {:id => 1, :stack => 0}, {:id => 2, :stack => 10 } ]
        t.simulate!

        t.active_players.size.should == 1
      end
    end
  end

  describe "when the dealer goes all-in on the ante" do
    let(:table) {
      HoldEmPokerTable.new(
        :deck => deck,
        :ante => 20,
        :players => [{:id => 1, :stack => 5}, {:id => 2, :stack => 25}])
    }

    before { table.simulate! [
      {:player_id=>2, :action=>"bet", :amount=>5}
    ] }

    it "should be in the showdown phase" do
      table.round.should == 'showdown'
    end
  end

  describe "with three players" do
    let(:table) {
      HoldEmPokerTable.new deck: deck, big_blind: 10, players: [
        { :id => 1, :stack => 20 },
        { :id => 2, :stack => 20 },
        { :id => 3, :stack => 20 }
      ]
    }

    it "lets the last player win if 1 and 2 fold" do
      table.simulate! [
        { :player_id => 1, :action => "fold" },
        { :player_id => 2, :action => "fold" }
      ]

      table.round.should == 'showdown'
      table.winners.should == [{ :player_id => 3, :winnings => 15 }]
    end
  end

  describe "with three players of different stack sizes" do
    let(:deck) {
      "AH KC 2H AC KH 3C AS KD 5S AD QS 7D KS QH TC"
    }
    let(:table) {
      HoldEmPokerTable.new deck: deck, big_blind: 5, players: [
        { :id => 1, :stack => 20 },
        { :id => 2, :stack => 40 },
        { :id => 3, :stack => 60 }
      ]
    }

    context "handling side pots" do
      context "when there are three players and one goes all in" do
        before :each do
          table.simulate! [
            { player_id: 1, action: "bet", amount: 15 },
            { player_id: 2, action: "bet", amount: 10 },
            { player_id: 3, action: "bet", amount: 0 },
            # flop
            { player_id: 2, action: "bet", amount: 0 },
            { player_id: 3, action: "bet", amount: 0 },
            # turn
            { player_id: 2, action: "bet", amount: 0 },
            { player_id: 3, action: "bet", amount: 0 },
            # river
            { player_id: 2, action: "bet", amount: 0 },
            { player_id: 3, action: "bet", amount: 0 }
          ]
        end

        it "awards 60 chips to player 1" do
          table.winners.should include({ :player_id=>1, :winnings=>60})
        end

        it "has 20 chips in the side pot" do
          table.winners.should include({:player_id=>2, :winnings=>20})
        end
      end

      context "when the side pot forms after the initial bets" do
        before :each do
          table.simulate! [
            # player 1 starts the betting
            { player_id: 1, action: "bet", amount: 10 },
            { player_id: 2, action: "bet", amount: 0 },
            { player_id: 3, action: "bet", amount: 0 },
            # flop
            { player_id: 2, action: "bet", amount: 5 },
            { player_id: 3, action: "bet", amount: 0 },
            { player_id: 1, action: "bet", amount: 0 },
            # turn
            { player_id: 2, action: "bet", amount: 5 },
            { player_id: 3, action: "bet", amount: 0 },
            # river
            { player_id: 2, action: "bet", amount: 0 },
            { player_id: 3, action: "bet", amount: 0 }
          ]
        end

        it "awards 60 chips to player 1" do
          table.winners.should include({ :player_id=>1, :winnings=>60})
        end

        it "has 20 chips in the side pot" do
          table.winners.should include({:player_id=>2, :winnings=>10})
        end
      end

      context "when there are two side pots" do
        let(:deck) {
          "AC KC QC JC AS KS QS JS 2S AH 2D KH 2H QH 2C JH 3S AD KD QD JD"
        }
        let(:table) {
          HoldEmPokerTable.new deck: deck, ante: 5, players: [
            { :id => 1, :stack => 20 },
            { :id => 2, :stack => 30 },
            { :id => 3, :stack => 40 },
            { :id => 4, :stack => 60 }
        ]
        }
        before {
          table.simulate! [
            { player_id: 4, action: "bet", amount: 0  },
            { player_id: 1, action: "bet", amount: 15 },
            { player_id: 2, action: "bet", amount: 10 },
            { player_id: 3, action: "bet", amount: 10 },
            { player_id: 4, action: "bet", amount: 0 },
            # flop
            { player_id: 3, action: "bet", amount: 0 },
            { player_id: 4, action: "bet", amount: 0 },
            # turn
            { player_id: 3, action: "bet", amount: 0 },
            { player_id: 4, action: "bet", amount: 0 },
            # river
            { player_id: 3, action: "bet", amount: 0 },
            { player_id: 4, action: "bet", amount: 0 }
          ]
        }

        it "should award 80 chips to player 1" do
          table.winners.should include({ :player_id=>1, :winnings=>80})
        end

        it "should award 30 chips to player 2" do
          table.winners.should include({:player_id=>2, :winnings=>30})
        end

        it "should award 20 chips to player 3" do
          table.winners.should include({:player_id=>3, :winnings=>20})
        end
      end

      context "when the chip leader wins the main pot do" do
        let(:table) {
          HoldEmPokerTable.new deck: deck, ante: 5, players: [
            { :id => 1, :stack => 100 },
            { :id => 2, :stack => 50 },
            { :id => 3, :stack => 20 }
          ]
        }
        before :each do
          table.simulate! [
            { player_id: 2, action: "bet", amount: 0 },
            { player_id: 3, action: "bet", amount: 0 },
            { player_id: 1, action: "bet", amount: 95 },
            { player_id: 2, action: "bet", amount: 0 },
            { player_id: 3, action: "bet", amount: 0 },
          ]
        end

        it "awards 170 to player 1" do
          table.winners.should include({ :player_id => 1, :winnings => 170})
        end
      end
    end
  end

  describe "two player table when player two goes all in and the other calls/raises" do
    let(:t) {
      HoldEmPokerTable.new( players: [{:id=>75, :stack=>492}, {:id=>74, :stack=>258}],
        ante: 20,
        deck: "2C AC 4H AS 4C KC 8S 7D 6C 5D 3H 4D KH AD TC AH 7H 6S KD 5H 8D 9C 8C JD QS 2H 6H QH 4S 2D 3C TS 3D KS 9D 8H JS 7S 5S 7C TD QD 5C 6D JH QC 9S 2S TH JC")
    }
    before {
      t.simulate! [
        {:player_id=>75, :action=>"bet", :amount=>0, :cards=>nil},
        {:player_id=>74, :action=>"bet", :amount=>238, :cards=>nil},
        {:player_id=>75, :action=>"bet", :amount=>7, :cards=>nil},
      ]
    }

    it "gives player 74 his pot and refunds 75" do
      t.winners.should == [ {:player_id => 74, :winnings => 516}, {:player_id => 75, :winnings => 7 } ]
    end
  end

  describe "two player table when player one goes all in and the other calls/raises" do
    let(:t) {
      HoldEmPokerTable.new( players: [{:id=>75, :stack=>100}, {:id=>74, :stack=>50}],
        ante: 20,
        deck: "Ac 5d 2c 3d 3c 9s 4c 8h 5c Ad 6d Ah")
    }
    before {
      t.simulate! [
        {:player_id=>74, :action=>"bet", :amount=>0, :cards=>nil},
        {:player_id=>75, :action=>"bet", :amount=>40, :cards=>nil},
        {:player_id=>74, :action=>"bet", :amount=>0, :cards=>nil},
      ]
    }

    it "gives player 75 the whole pot" do
      t.winners.should == [ {:player_id => 75, :winnings => 110} ]
    end
  end

  describe "logging" do
    let(:table) do
      t = HoldEmPokerTable.new deck: deck, ante: 15, players: [
        { :id => 1, :stack => 20 },
        { :id => 2, :stack => 20 },
        { :id => 3, :stack => 20 }
      ]
      t.simulate! [
        { :player_id => 1, :action => "fold" },
        { :player_id => 2, :action => "fold" }
      ]
      t
    end

    it "outputs a log of actual actions" do
      table.log.should == [
        { :round => "deal" },
        { :player_id => 2, :action => "ante", :amount => 7  },
        { :player_id => 3, :action => "ante", :amount => 15 },
        { :player_id => 1, :action => "fold" },
        { :player_id => 2, :action => "fold" },
        { :round => "showdown" },
        { :player_id => 3, :action => "won", :amount => 22  }
      ]
    end
  end

  describe "other types of bets" do
    let(:deck) { "AH KC 2H AC KH 3C AS KD 5S AD QS 7D KS QH TC" }
    let(:table) {
      HoldEmPokerTable.new deck: deck, ante: 5, players: [
        { :id => 1, :stack => 100 },
        { :id => 2, :stack => 50 },
        { :id => 3, :stack => 20 }
      ]
    }

    describe "call" do
      it "is a valid action" do
        table.simulate! [ { player_id: 1, action: "bet", amount: 95 } ]

        table.valid_action?({ player_id: 2, action: "call" }).should be_true
      end

      context "in a full game" do
        before :each do
          table.simulate! [
            { player_id: 1, action: "bet", amount: 95 },
            { player_id: 2, action: "call", amount: 0 },
            { player_id: 3, action: "call", amount: 0 },

            { player_id: 1, action: "call", amount: 0 },
            { player_id: 2, action: "call", amount: 0 },
            { player_id: 3, action: "call", amount: 0 },

            { player_id: 1, action: "call", amount: 0 },
            { player_id: 2, action: "call", amount: 0 },
            { player_id: 3, action: "call", amount: 0 },

            { player_id: 1, action: "call", amount: 0 },
            { player_id: 2, action: "call", amount: 0 },
            { player_id: 3, action: "call", amount: 0 },
          ]
        end

        it "works the same as bet 0" do
          table.winners.should include({ :player_id => 1, :winnings => 170})
        end
      end
    end

    describe "raise" do
      it "is a valid action" do
        table.simulate! [ { player_id: 1, action: "bet", amount: 5 } ]

        table.valid_action?(player_id: 2, action: "raise", amount: 5).should be_true
      end

      it "works the same as bet" do
        table.simulate! [
            { player_id: 1, action: "bet", amount: 5 },
            { player_id: 2, action: "call", amount: 0 },
            { player_id: 3, action: "call", amount: 0 },

            { player_id: 2, action: "raise", amount: 0 },
            { player_id: 3, action: "raise", amount: 0 },
            { player_id: 1, action: "raise", amount: 5 },
            { player_id: 2, action: "call", amount: 0 },
            { player_id: 3, action: "call", amount: 0 },

            { player_id: 2, action: "call", amount: 0 },
            { player_id: 3, action: "call", amount: 0 },
            { player_id: 1, action: "call", amount: 0 },

            { player_id: 2, action: "call", amount: 0 },
            { player_id: 3, action: "call", amount: 0 },
            { player_id: 1, action: "call", amount: 0 },
        ]

        table.winners.should include(player_id: 1, winnings: 45)
      end
    end

    describe "check" do
      it "is a valid action when the call amount is zero" do
        table.simulate! [
           { player_id: 1, action: "bet", amount: 5 },
           { player_id: 2, action: "call", amount: 0 },
           { player_id: 3, action: "call", amount: 0 }
        ]

        table.valid_action?( player_id: 2, action: "check" ).should be_true
      end

      it "is not a valid action when the call amount is not zero" do
        table.simulate! [
           { player_id: 1, action: "bet", amount: 5 },
           { player_id: 2, action: "call", amount: 0 },
           { player_id: 3, action: "call", amount: 0 },
           { player_id: 2, action: "bet", amount: 5 }]

        table.valid_action?( player_id: 3, action: "check" ).should be_false
      end

      it "works the same as bet 0 in the right condition" do
        table.simulate! [
           { player_id: 1, action: "bet", amount: 5 },
           { player_id: 2, action: "call", amount: 0 },
           { player_id: 3, action: "call", amount: 0 },

           { player_id: 2, action: "check"},
           { player_id: 3, action: "check"},
           { player_id: 1, action: "check"},

           { player_id: 2, action: "check"},
           { player_id: 3, action: "check"},
           { player_id: 1, action: "check"},

           { player_id: 2, action: "check"},
           { player_id: 3, action: "check"},
           { player_id: 1, action: "check"}
        ]

        table.winners.should include(:player_id => 1, :winnings => 30)
      end
    end
  end
end
