require 'zulip'
require 'pry'
require './auth.rb'


class Game
  attr_reader :player_one, :player_two
  attr_accessor :board, :challenge
  def initialize(client)
    @client    = client
    @challenge = false
  end

  def initialize_board
    bare = Array.new(9) { Array.new(9) { '_' } }
    top = ['_'] + ('a'..'z').to_a
    left = 0

    bare[1..-1].each { |p| p[0] = left += 1 }
    bare[0] = top[0..8]
    @board = bare.map { |x| x.join("|") }.join("\n")
  end

  def not_ready?
    (@player_one && @player_two).nil?
  end

  def play_turn(msg)
    if @player_one.turn
      # @client.send_message("bot-test", "JUST KIDDING! The game isn't read yet.", 'go')
      @player_one.turn = false
      @player_two.turn = true
      make_move(msg, @player_one)
    else
      @player_one.turn = true
      @player_two.turn = false
      make_move(msg, @player_two)
    end
  end

  def make_move(msg, player)
    move = msg.content[/(?<=```).+(?=```)/]
    x, y = move.split('')
    x    = x.to_i

    convert_board_to :array

    y = @board[0].index(y)

    if @board[x][y] != "_"
      @client.send_message("bot-test", "invalid selection! try again!", "go")
      convert_board_to :string
    else
      @board[x.to_i][y] = player.stone
      adjacent_tiles(x, y).each do |tile|
        if tile[:liberties] == 0 && tile[:value] == player.opposite
          x, y = tile[:loc]
          @board[x][y] = "-"
        end
      end
    end
    convert_board_to :string
    show_board
  end

  def convert_board_to(type=nil)
    if type == :array
      @board = @board.split("\n").map { |x| x.split("|") }
    elsif type == :string
      @board = @board.map { |x| x.join("|") }
      @board = @board.join("\n")
    end
    puts "board:\n #{@board}"
  end

  def adjacent_tiles(x,y)
    [
      { :value => @board[x][y+1], :loc => [x,y+1], :liberties => liberty_count(x, y+1) }, 
      { :value => @board[x][y-1], :loc => [x,y-1], :liberties => liberty_count(x, y-1) },
      { :value => @board[x+1][y], :loc => [x+1,y], :liberties => liberty_count(x+1, y) },
      { :value => @board[x-1][y], :loc => [x-1,y], :liberties => liberty_count(x-1, y) }
    ]
  end

  def liberty_count(x,y)
    [@board[x][y+1], @board[x][y-1], @board[x-1][y], @board[x+1][y]].count('_')
  end

  def show_board
    @client.send_message("bot-test", "```\n#{@board}\n```", 'go')
  end

  def create_player_one(name)
    @player_one = Player.new(name, 'black', "\u25CF")
    @player_one.turn = true
  end

  def select_player_two(msg)
    name = msg.content[/(?<=@\*\*).+(?=\*\*)/]
    puts name
    @player_two = Player.new(name, 'white', "\u25CB")
  end
end

class Player < Game
  attr_reader :name, :color, :stone
  attr_accessor :turn
  def initialize(name, color, stone)
    @name  = name
    @color = color
    @stone = stone
    @turn  = false
  end

  def opposite
    if stone == "\u25CF"
      "\u25CB"
    end
  end

  def found?
    
  end
end



@client.stream_messages do |msg|
  if msg.stream == 'go' && msg.sender_email != @client.email_address
    # this filters out the messages that come from the bot
    # if it's not from itself
    #
    if @game
      if !@game.not_ready? && msg.content =~ /```[0-9][a-zA-Z]```/
        @game.play_turn(msg)
      else 
        puts "#{msg.sender_full_name}"
        if msg.sender_full_name == @game.player_one.name
          @game.select_player_two(msg)
          @client.send_message("bot-test", "#{@game.player_one.name}! BEGIN!", 'go') if @game.not_ready?
          @game.challenge = true
        end
      end
    else
      if msg.content.include?("```")
        content = msg.content[/(?<=```).+(?=```)/]
        if content.upcase == 'START'
          @game = Game.new(@client)
          @game.create_player_one(msg.sender_full_name)
          @game.initialize_board
          @game.show_board
          @client.send_message("bot-test", "Ping your opponent to get the game started.", "go")
        end
      end
    end
  end
end


