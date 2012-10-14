require 'ruby-poker'

class PokerTable
  DRAW_LIMIT = 3
  DEAL_SIZE = 5

  attr_accessor :players, :deck, :actions, :ante, :round, :pot, :winners, :current_player

  def initialize(params={deck:""})
    @deck = params[:deck].split(" ")
    @players = params[:players] || []
    @actions = []
    @ante = params[:ante]
    @pot = 0

    @players.each { |p| p[:initial_stack] = p[:stack] }
  end

  def simulate!(actions=[])
    if self.actions.empty?
      # Start the hand, then simulate actions.
      start_deal!
    end

    # Push any new actions and start simulating.
    self.actions += actions

    actions.each do |action|
      react_to!(action)
    end
  end

  def active_players
    players.reject { |p| p[:folded] || p[:kicked] }
  end

  def stack_changes
    active_players.reduce({}) { |h, player|
      h[player[:id]] = player[:stack] - player[:initial_stack]
      h
    }
  end

  def minimum_bet
    active_players.map{ |p| p[:latest_bet] || 0 }.max
  end

  def maximum_bet
    minimum_bet + active_players.map{ |p| p[:stack] }.min
  end

  def valid_action?(action)
    player = find_player(action[:player_id])

    return false unless @current_player == player

    case action[:action]
    when "bet" # Absolute amount!
      if betting_round?
        amount = action[:amount].to_i
        raised_amount = amount - (player[:latest_bet] || 0)

        amount >= self.minimum_bet &&
        amount <= self.maximum_bet &&
        raised_amount <= player[:stack] 
      else
        false
      end
    when "replace" # List of cards!
      if draw_round?
        action[:cards].all? { |c|
          player[:hand].include?(c)
        } && action[:cards].size < DRAW_LIMIT
      else
        false
      end
    end
  end


private
  def ante_up!
    players.each do |player|
      kick!(player) unless player[:stack] >= ante
      bet!(player, ante)
    end
  end

  def deal_cards!
    active_players.each do |player|
      player[:hand] = []
    end

    DEAL_SIZE.times do
      active_players.each do |player|
        player[:hand].push @deck.delete_at(0)
      end
    end
  end

  def fold!(player)
    puts "Player #{player[:id]} folds."

    player[:folded] = true
    next_player!
  end

  def kick!(player)
    player[:kicked] = true
    next_player!
  end

  def bet!(player, amount)
    puts "Player #{player[:id]} raises their bet to #{amount}."
    player[:latest_bet] ||= 0
    raised_amount = amount - player[:latest_bet]

    player[:latest_bet] = amount
    player[:stack] -= raised_amount
    @pot += raised_amount

    next_player!
  end

  def replace!(player, cards)
    puts "Player #{player[:id]} chooses to replace cards #{cards}"
    player[:hand] -= cards
    (DEAL_SIZE - player[:hand].size).times do
      player[:hand].push @deck.delete_at(0)
    end

    player[:replaced] = true
    next_player!
  end

  def next_player!
    # Everyone else folded, so go to showdown.
    if active_players.size == 1
      showdown!
    end

    # Find the first player after @current player who's active.
    players.size.times do
      puts "current player: #{@current_player}"
      next_index = (players.index(@current_player) + 1) % players.size
      @current_player = players[next_index]
      break if active_players.include? @current_player
    end 
  end

  ## ACTION HANDLING

  def react_to!(action)
    player = find_player(action[:player_id])

    if player != @current_player
      # Ignore.
    elsif valid_action? action
      case action[:action]
      when "bet" # Absolute amount!
        bet!(player, action[:amount].to_i)
      when "replace" # List of cards!
        replace!(player, action[:cards])
      when "fold" # Kay
        fold!(player)
      end
    else
      fold!(player)
    end

    update_round!
  end

  def update_round!
    if betting_round?
      if active_players.all? { |p| p[:latest_bet] == self.minimum_bet }
        # Betting over, clear bets and move to the next round.
        clear_bets!
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

  ## ROUNDS

  def start_deal!
    self.round = 'deal'
    @current_player = @players.first
    ante_up!
    deal_cards!
  end

  def start_draw!
    @round = 'draw'
    @current_player = @players.first
  end

  def start_post_draw!
    @round = 'post_draw'
    @current_player = @players.first
  end

  def showdown!
    @round = 'showdown'

    if active_players.size > 1
      winning_hand = active_players.map { |p| PokerHand.new(p[:hand]) }.max
    
      winners = active_players.select { |p|
        PokerHand.new(p[:hand]) == winning_hand
      }
    else
      winners = active_players
    end
    
    pot_per_winner = @pot / winners.size
    @winners = winners.collect do |winner|
      allotment = winner == winners.last ? @pot : pot_per_winner
      @pot -= allotment

      { player_id: winner[:id],
        winnings: allotment }
    end

    hand_out_winnings!
  end

  ## MISC
  def hand_out_winnings!
    @winners.each do |winner|
      player = @players.find { |p| p[:id] == winner[:player_id] }
      player[:stack] += winner[:winnings]
    end
  end

  def clear_bets!
    active_players.each do |p|
      p[:latest_bet] = nil
    end
  end

  def betting_round?
    ['deal', 'post_draw'].include? self.round
  end

  def draw_round?
    'draw' == self.round
  end

  def find_player(id)
    players.find {|p| p[:id] == id}
  end
end
