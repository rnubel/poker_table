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

        it "deals cards and takes the ante of each player" do
          table.players.first[:stack].should == 5
          table.players.first[:hand].should == ["5H","9C","QH","2C","4H"]

          table.players.last[:stack].should == 10
          table.players.last[:hand].should == ["AS","TH","QS","3C","AC"]
        end

        it "sets the round as 'deal'" do
          table.round.should == 'deal'
        end
      end
    end
  end
end
