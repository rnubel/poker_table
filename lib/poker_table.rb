require 'ruby-poker'

class PokerTable
  DRAW_LIMIT = 3
  DEAL_SIZE = 5

  attr_accessor :players, :deck, :actions, :ante, :round, :pot, :winners, :losers, :current_player, :log

  def initialize(params={deck:""})
    @deck = params[:deck].split(" ")
    @players = params[:players] || []
    @players.each { |p| p[:initial_stack] = p[:stack] }
    @actions = []
    @ante = params[:ante]
    @pot = 0

    @losers = []

    @log = []
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

    puts "##### START LOG"
    puts @log
    puts "##### END LOG"
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
      return false unless action[:cards].is_a? Enumerable
      if draw_round?
        action[:cards].all? { |c|
          player[:hand].include?(c)
        } && action[:cards].size < DRAW_LIMIT
      else
        false
      end
    when "fold" # Should always be allowed, if it's their turn.
      true
    end
  end


private
  def ante_up!
    players.each do |player|
      if player[:stack] < ante
        kick!(player)
      else
        ante!(player, ante)
      end
    end

    if active_players.size <= 1
      showdown!
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
    #puts "Player #{player[:id]} folds."
    log << { :player_id => player[:id], :action => "fold" }

    player[:folded] = true
    next_player!
  end

  def kick!(player)
    log << { :player_id => player[:id], :action => "lost", :stack_surrendered => player[:stack] }
 
    @losers << { :player_id => player[:id] }

    @pot += player[:stack]
    player[:stack] = 0

    player[:kicked] = true
  end

  def set_players_bet!(player, amount)
    player[:latest_bet] ||= 0
    raised_amount = amount - player[:latest_bet]
    player[:latest_bet] = amount
    player[:stack] -= raised_amount
    @pot += raised_amount
  end

  def ante!(player, amount)
    log << { :player_id => player[:id], :action => "ante", :amount => amount }
    # puts "Player #{player[:id]} antes #{amount}."

    set_players_bet!(player, amount)
  end

  def bet!(player, amount)
    log << { :player_id => player[:id], :action => "bet", :amount => amount }
    # puts "Player #{player[:id]} raises their bet to #{amount}."
  
    set_players_bet!(player, amount)
    player[:bet_this_round] = true

    next_player!
  end

  def replace!(player, cards)
    log << { :player_id => player[:id], :action => "replace", :cards => cards }
    # puts "Player #{player[:id]} chooses to replace cards #{cards}"
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
      if active_players.size <= 1 ||
         (  active_players.size > 1 &&
            everyones_bet? &&
            active_players.all? { |p| p[:latest_bet] == self.minimum_bet } )
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

  def everyones_bet?
    self.active_players.all? { |p| p[:bet_this_round] }
  end

  ## ROUNDS
  def set_round(round)
    self.round = round

    active_players.each { |p| p[:bet_this_round] = false }

    log << { :round => round }
  end

  def start_deal!
    set_round('deal')
    @current_player = @players.first
    ante_up!
    deal_cards!
  end

  def start_draw!
    set_round('draw')  
    @current_player = @players.first
  end

  def start_post_draw!
    set_round('post_draw')
    @current_player = @players.first
  end

  def showdown!
    set_round('showdown')
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

      @log << { :player_id => player[:id], :action => "won", :amount => winner[:winnings] }

      player[:stack] += winner[:winnings]
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
