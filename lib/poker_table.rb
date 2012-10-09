class PokerTable
  attr_accessor :players, :deck, :actions, :ante, :round, :pot

  def initialize(params={deck:""})
    @deck = params[:deck].split(" ")
    @players = params[:players]
    @actions = []
    @ante = params[:ante]
    @pot = 0
  end

  def simulate!(actions=[])
    self.actions = actions
   
    # Start the hand, then simulate actions.
    self.round = 'deal'
    ante_up!
    deal_cards!

    actions.each do |action|
      react_to!(action)
    end
  end

  def active_players
    players.reject { |p| p[:folded] || p[:kicked] }
  end

  def minimum_bet
    active_players.map{ |p| p[:latest_bet] || 0 }.max
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

    5.times do
      active_players.each do |player|
        player[:hand].push @deck.delete_at(0)
      end
    end
  end

  def fold!(player)
    player[:folded] = true
  end

  def kick!(player)
    player[:kicked] = true
  end

  def bet!(player, amount)
    puts "Player #{player[:id]} raises their bet to #{amount}."
    player[:latest_bet] ||= 0
    raised_amount = amount - player[:latest_bet]

    player[:latest_bet] = amount
    player[:stack] -= raised_amount
    @pot += raised_amount
  end

  def replace!(player, cards)
    puts "Player #{player[:id]} chooses to replace cards #{cards}"
    player[:hand] -= cards
    (5 - player[:hand].size).times do
      player[:hand].push @deck.delete_at(0)
    end

    player[:replaced] = true
  end

  def react_to!(action)
    player = find_player(action[:player_id])

    if valid_action? action
      case action[:action]
      when "bet" # Absolute amount!
        if betting_round?
          bet!(player, action[:amount].to_i)
        else
          fold!(player)
        end
      when "replace" # List of cards!
        if draw_round?
          replace!(player, action[:cards])
        else
          # Wat
        end
      end
    else
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

  def start_draw!
    @round = 'draw'
  end

  def showdown!

  end

  def start_post_draw!
    @round = 'post_draw'
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

  def valid_action?(action)
    true
  end
end
