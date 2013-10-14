class HoldEmPokerTable < PokerTable
  DRAW_LIMIT = 0
  DEAL_SIZE = 2
  FLOP_SIZE = 3
  BETTING_ROUNDS = ['deal', 'flop', 'turn', 'river'].freeze

  def valid_action?(action)
    player = find_player(action[:player_id])

    return false unless @current_player == player

    map_action!(action) # Handle call, check, etc.

    case action[:action]
    when "bet" # :amount => Relative amount to previous actual bet
      if betting_round?
        raise_amount = action[:amount].to_i
        call_amount = minimum_bet - (player[:current_bet] || 0)

        return false if action[:check] && raise_amount + call_amount > 0

        if raise_amount < 0
          false
        elsif player[:stack] < call_amount # Player cannot call; only actions are all-in or fold. bet 0 === all-in
          raise_amount == 0
        else
          # Does player have enough chips?
          player[:stack] >= call_amount + raise_amount
        end
      else
        false
      end
    when "fold" # Should always be allowed, if it's their turn.
      true
    end
  end

private
  def replace!(player, cards)
    raise RuntimeError, "can not replace cards in a HoldEmPokerTable"
  end

  def update_round!
    if betting_round?
      if active_players.size <= 1 ||
         (  active_players.size > 1 &&
            everyones_bet? &&
            active_players.all? { |p| p[:current_bet] == self.minimum_bet || p[:all_in] } )
        # Betting over, move to the next round.
        if @round == 'deal'
          start_flop!
        elsif @round == 'flop'
          start_turn!
        elsif @round == 'turn'
          start_river!
        elsif @round == 'river'
          showdown!
        end
      end
    end
  end

  def start_deal!
    set_round('deal')
    clear_community_cards!
    take_blinds!
    deal_cards!
    #@current_player = active_players.reverse.find { |p| !p[:current_bet].nil? } || active_players.first
    next_player!
  end

  def start_flop!
    set_round('flop')
    deal_community_cards!(FLOP_SIZE)
    @current_player = active_players.first
    if all_but_one_all_in?
      update_round!
    else
      next_player!
    end
  end

  def start_turn!
    set_round('turn')
    deal_community_cards!(1)
    @current_player = active_players.first
    if all_but_one_all_in?
      update_round!
    else
      next_player!
    end
  end

  def start_river!
    set_round('river')
    deal_community_cards!(1)
    @current_player = active_players.first

    if all_but_one_all_in?
      update_round!
    else
      next_player!
    end
  end

  def deal_community_cards!(card_count)
    # burn and turn, baby.
    @deck.delete_at(0) # note to trey: the players never see the deck. why bother?

    cards_dealt = card_count.times.collect do
      card = @deck.delete_at(0)
      community_cards.push card
      card
    end

    log <<  { :community_cards => cards_dealt }
  end

  def big_blind
    @ante
  end

  def small_blind
    big_blind / 2
  end

  private
  def take_blinds!
    # players[0] is the dealer. they do not place a blind
    # players[1] places the small blind
    # players[2] places the big blind

    @current_player = active_players[2 % active_players.size]

    [ [active_players[1]                        , small_blind], 
      [active_players[2 % active_players.size]  , big_blind]
    ].each do |player, blind|
      if player[:stack] == 0
        kick!(player)
      else
        ante!(player, [player[:stack], blind].min)
      end
    end

    if active_players.size <= 1
      showdown!
    end
  end
end
