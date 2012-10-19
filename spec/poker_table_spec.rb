require 'spec_helper'

describe PokerTable do
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
        PokerTable.new deck: deck,
                       ante: 5,
                       players: players
      }

      it "should split the deck into cards" do
        table.deck.should == deck.split(" ")
      end
    end

    context "when simulating play from a list of actions" do
      let(:table) {
        PokerTable.new deck: deck,
                       ante: 5,
                       players: players
      }

      context "when given an empty list of actions" do
        before :each do
          table.simulate!([])
        end

        it "should deal cards and take the ante of each player" do
          table.players.first[:stack].should == 5
          table.players.first[:hand].should == ["5H","9C","QH","2C","4H"]

          table.players.last[:stack].should == 10
          table.players.last[:hand].should == ["AS","TH","QS","3C","AC"]
        end

        it "should set the round as being 'deal'" do
          table.round.should == 'deal'
        end
      end

      context "when given a valid sequence of bets to end the first round" do
        before :each do
          table.simulate!([
            { player_id: "playerone", action: "bet", amount: 6 },
            { player_id: "playertwo", action: "bet", amount: 6 } 
          ])
        end

        it "should show the round as being 'draw'" do
          table.round.should == 'draw'
        end
      end

      context "when given a valid, more complex sequence of bets to end the first round" do
        before :each do
          table.simulate!([
            { player_id: "playerone", action: "bet", amount: 6 },
            { player_id: "playertwo", action: "bet", amount: 7 },
            { player_id: "playerone", action: "bet", amount: 8 },
            { player_id: "playertwo", action: "bet", amount: 8 }
          ])
        end

        it "should still have two active players" do
          table.active_players.size.should == 2
        end

        it "should show the round as being 'draw'" do
          table.round.should == 'draw'
        end
      end

      context "when given valid actions to end the first round and replace cards" do
        before :each do
          table.simulate!([
            { player_id: "playerone", action: "bet", amount: 6 },
            { player_id: "playertwo", action: "bet", amount: 6 },
            { player_id: "playerone", action: "replace", cards: ["5H"] },
            { player_id: "playertwo", action: "replace", cards: ["QS", "TH"] }
          ])
        end

        it "should update the players' hands" do
          table.players.first[:hand].should == ["9C","QH","2C","4H", "JS"] 
          table.players.last[:hand].should == ["AS","3C","AC", "JC", "KC"] 
        end

        it "should show the round as being 'post_draw'" do
          table.round.should == 'post_draw'
        end
      end

      context "when given valid actions to end a full hand" do
        before :each do
          table.simulate!([
            { player_id: "playerone", action: "bet", amount: 6 },
            { player_id: "playertwo", action: "bet", amount: 6 },
            { player_id: "playerone", action: "replace", cards: ["5H"] },
            { player_id: "playertwo", action: "replace", cards: ["QS", "TH"] },
            { player_id: "playerone", action: "bet", amount: 6 },
            { player_id: "playertwo", action: "bet", amount: 7 },
            { player_id: "playerone", action: "bet", amount: 8 },
            { player_id: "playertwo", action: "bet", amount: 8 },
          ])
        end

        it "should show the round as being 'showdown'" do
          table.round.should == 'showdown'
        end

        it "should know the round's winners and their winnings" do
          table.winners.should == [{ player_id: "playertwo", winnings: 16 }]
        end

        it "lists total stack changes per player" do
          table.stack_changes.should == { "playerone" => -8, "playertwo" => 8 }
        end
      end

      context "when given invalid actions" do
        it "should ignore invalid bets and wait for a valid bet" do
          table.simulate!([
              { player_id: "playerone", action: "bet", amount: 6 },
              { player_id: "playertwo", action: "bet", amount: 5 },
            ])

          table.current_player[:id].should == "playertwo"
        end

        it "should recognize an invalid bet after simulating" do
          table.simulate!([
              { player_id: "playerone", action: "bet", amount: 6 }
            ])

          table.valid_action?(
              { player_id: "playertwo", action: "bet", amount: 5 }
          ).should be_false
        end

        it "should recognize when its not a players turn" do
          table.simulate!([
              { player_id: "playerone", action: "bet", amount: 6 }
            ])

          table.valid_action?(
              { player_id: "playerone", action: "bet", amount: 7 }
          ).should be_false
        end

        it "should require the cards parameter for replacing" do
          table.simulate!([
              { player_id: "playerone", action: "bet", amount: 6 },
              { player_id: "playertwo", action: "bet", amount: 6 }
            ])

         table.valid_action?(player_id: "playerone", action: "replace")
            .should be_false
        end
      end

      context "when given folds" do
        it "should allow the action 'fold" do
          table.simulate!([
              { player_id: "playerone", action: "bet", amount: 6 }
            ])

          table.valid_action?(player_id: "playertwo", action: "fold")
            .should be_true
        end

        it "should end the round if N-1 players fold with the Nth the winner" do
          table.simulate!([
              { player_id: "playerone", action: "fold" }
            ])

          table.winners.first[:player_id].should == "playertwo"
        end
      end

      describe "player rotation" do
        it "should start off at the dealer's position" do
          table.simulate!([])
          table.current_player[:id].should == "playerone"
        end

        it "should rotate to the next player if that player folds" do
          table.simulate!([
              { player_id: "playerone", action: "fold" }
            ])
          table.current_player[:id].should == "playertwo"
        end

        it "should not care if both players say they fold" do
          table.simulate!([
              { player_id: "playerone", action: "fold" },
              { player_id: "playertwo", action: "fold" }
            ])
        end
      end
    end

    describe "#active_players" do
      it "should exclude folded players" do
        t = PokerTable.new
        t.expects(:players).returns([{:folded => true}, {}])
        t.active_players.should == [{}]
      end

      it "should exclude kicked players" do
        t = PokerTable.new
        t.expects(:players).returns([{:kicked => true}, {}])
        t.active_players.should == [{}]
      end
    end

    describe "#ante_up!" do
      it "should force a player all in if they cannot meet the ante" do
        t = PokerTable.new deck: deck,
                       ante: 12,
                       players: players
        t.simulate!

        t.active_players.size.should == 2
      end

      it "should kick a player out if they have zero chips" do
        t = PokerTable.new deck: deck,
                       ante: 12,
                       players: [ {:id => 1, :stack => 0}, {:id => 2, :stack => 10 } ]
        t.simulate!

        t.active_players.size.should == 1
      end
    end
  end

  describe "when the dealer goes all-in on the ante" do
    let(:table) {
      PokerTable.new(
        :deck => deck,
        :ante => 20,
        :players => [{:id => 1, :stack => 5}, {:id => 2, :stack => 25}])
    }

    before { table.simulate! [
      {:player_id=>2, :action=>"bet", :amount=>25}
    ] }

    it "should be in the draw phase" do
      table.round.should == 'draw'
    end
  end

  describe "with three players" do
    let(:table) {
      PokerTable.new deck: deck, ante: 15, players: [
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
      table.winners.should == [{ :player_id => 3, :winnings => 45 }]
    end
  end

  describe "with three players of different stack sizes" do
    let(:deck) {
      "AH KC 2H AC KH 3C AS KD 5S AD QS 7D KS QH TC"
    }
    let(:table) {
      PokerTable.new deck: deck, ante: 5, players: [
        { :id => 1, :stack => 20 },
        { :id => 2, :stack => 40 },
        { :id => 3, :stack => 60 }
      ]
    }

    context "handling side pots" do
      context "when there are three players and one goes all in" do
        before :each do
          table.simulate! [
            { player_id: 1, action: "bet", amount: 20 },
            { player_id: 2, action: "bet", amount: 30 },
            { player_id: 3, action: "bet", amount: 30 },
            { player_id: 1, action: "replace", cards: [] },
            { player_id: 2, action: "replace", cards: [] },
            { player_id: 3, action: "replace", cards: [] },
            { player_id: 2, action: "bet", amount: 30 },
            { player_id: 3, action: "bet", amount: 30 }
          ]
        end

        it "should award 60 chips to player 1" do
          table.winners.should include({ :player_id=>1, :winnings=>60})
        end

        it "should have 20 chips in the side pot" do
          table.winners.should include({:player_id=>2, :winnings=>20})
        end

      end

      context "when there are two side pots" do
        let(:deck) {
          "AC KC QC JC AS KS QS JS AH KH QH JH AD KD QD JD 2C 2D 2S 2H"
        }
        let(:table) {
          PokerTable.new deck: deck, ante: 5, players: [
            { :id => 1, :stack => 20 },
            { :id => 2, :stack => 30 },
            { :id => 3, :stack => 40 },
            { :id => 4, :stack => 60 }
        ]
        }
        before {
          table.simulate! [
            { player_id: 1, action: "bet", amount: 20 },
            { player_id: 2, action: "bet", amount: 30 },
            { player_id: 3, action: "bet", amount: 40 },
            { player_id: 4, action: "bet", amount: 40 },
            { player_id: 1, action: "replace", cards: [] },
            { player_id: 2, action: "replace", cards: [] },
            { player_id: 3, action: "replace", cards: [] },
            { player_id: 4, action: "replace", cards: [] },
            { player_id: 3, action: "bet", amount: 40 },
            { player_id: 4, action: "bet", amount: 40 }
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
          PokerTable.new deck: deck, ante: 5, players: [
            { :id => 1, :stack => 100 },
            { :id => 2, :stack => 50 },
            { :id => 3, :stack => 20 }
          ]
        }
        before :each do
          table.simulate! [
            { player_id: 1, action: "bet", amount: 100 },
            { player_id: 2, action: "bet", amount: 50 },
            { player_id: 3, action: "bet", amount: 20 },
            { player_id: 1, action: "replace", cards: [] },
            { player_id: 2, action: "replace", cards: [] },
            { player_id: 3, action: "replace", cards: [] }
          ]
        end

        it "should award 170 to player 1" do
          table.winners.should include({ :player_id => 1, :winnings => 170})
        end
      end
    end
  end

  describe "logging" do
    let(:table) do
      t = PokerTable.new deck: deck, ante: 15, players: [
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

    it "should output a log of actual actions" do
      table.log.should == [
        { :round => "deal" },
        { :player_id => 1, :action => "ante", :amount => 15 },
        { :player_id => 2, :action => "ante", :amount => 15 },
        { :player_id => 3, :action => "ante", :amount => 15 },
        { :player_id => 1, :action => "fold" },
        { :player_id => 2, :action => "fold" },
        { :round => "showdown" },
        { :player_id => 3, :action => "won", :amount => 45 }
      ]
    end
  end
end
