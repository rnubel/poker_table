class DrawPokerTable < PokerTable
  DRAW_LIMIT = 3
  DEAL_SIZE = 5
  BETTING_ROUNDS = ['deal', 'post_draw'].freeze

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
    when "replace" # :cards => List of cards to replace
      return false unless action[:cards].is_a? Enumerable
      if draw_round?
        action[:cards].all? { |c|
          player[:hand].include?(c)
        } && action[:cards].size <= DRAW_LIMIT
      else
        false
      end
    when "fold" # Should always be allowed, if it's their turn.
      true
    end
  end

private
  def replace!(player, cards)
    log << { :player_id => player[:id], :action => "replace", :cards => cards }
    player[:hand] -= cards
    (DEAL_SIZE - player[:hand].size).times do
      player[:hand].push @deck.delete_at(0)
    end

    player[:replaced] = true
    next_player!
  end

  def update_round!
    if betting_round?
      if active_players.size <= 1 ||
         (  active_players.size > 1 &&
            everyones_bet? &&
            active_players.all? { |p| p[:current_bet] == self.minimum_bet || p[:all_in] } )
        # Betting over, move to the next round.
        if @round == 'deal'
          start_draw!
        elsif @round == 'post_draw'
          showdown!
        end
      end
    elsif draw_round? # currently in draw; check if all replacements are in
      if active_players.all? { |p| p[:replaced] }
        start_post_draw!
      end
    end
  end
end
