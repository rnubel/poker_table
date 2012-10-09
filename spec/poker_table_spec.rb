require 'spec_helper'

describe PokerTable do
  let(:deck){
    "5H AS 9C TH QH QS 2C 3C 4H 1C JS JC KC"
  }

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
        table.players.last[:hand].should == ["AS","TH","QS","3C","1C"]
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

      it "should have a pot of 12" do
        table.pot.should == 12
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

      it "should have a pot of 16" do
        table.pot.should == 16
      end
    end

    context "when given a valid sequence of bets to end the first round and replace cards" do
      before :each do
        table.simulate!([
          { player_id: "playerone", action: "bet", amount: 1 },
          { player_id: "playertwo", action: "bet", amount: 1 },
          { player_id: "playerone", action: "replace", cards: ["5H"] },
          { player_id: "playertwo", action: "replace", cards: ["QS", "TH"] }
        ])
      end

      it "should update the players' hands" do
        table.players.first[:hand].should == ["9C","QH","2C","4H", "JS"] 
        table.players.last[:hand].should == ["AS","3C","1C", "JC", "KC"] 
      end

      it "should show the round as being 'post_draw'" do
        table.round.should == 'post_draw'
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
    it "should remove players who cannot meet the ante" do
      t = PokerTable.new deck: deck,
                     ante: 15,
                     players: players
      t.simulate!

      t.active_players.size.should == 1
    end
  end
end
