class HoldEmPokerTable < PokerTable
  DRAW_LIMIT = 0
  DEAL_SIZE = 2
  FLOP_SIZE = 3
  BETTING_ROUNDS = ['deal', 'flop', 'turn', 'post_draw'].freeze

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
          start_post_draw!
        elsif @round == 'post_draw'
          showdown!
        end
      end
    end
  end

  def start_flop!
    deal_community_cards!(FLOP_SIZE)
    set_round('flop')
    @current_player = active_players.last
    if all_but_one_all_in?
      update_round!
    else
      next_player!
    end
  end

  def start_turn!
    deal_community_cards!(1)
    set_round('turn')
    @current_player = active_players.last
    if all_but_one_all_in?
      update_round!
    else
      next_player!
    end
  end

  def start_post_draw!
    deal_community_cards!(1)
    set_round('post_draw')
    @current_player = active_players.last

    if all_but_one_all_in?
      update_round!
    else
      next_player!
    end
  end

  def deal_community_cards!(card_count)
    # burn and turn, baby.
    @deck.delete_at(0)

    card_count.times do
      community_cards.push @deck.delete_at(0)
    end
  end
end
