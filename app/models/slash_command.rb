class SlashCommand
  attr_reader :input, :author

  def self.match?(content)
    content.to_s.lstrip.start_with?("/")
  end

  def initialize(input, author:)
    @input  = input.strip
    @author = author
    @command, @arg = @input.split(" ", 2)
  end

  # Returns the Message to save, or nil if nothing should be saved (bot handles it).
  def message
    return nil unless me?
    action = @arg.to_s
    Message.new(author:, content: "_\\* #{author} #{action}_")
  end

  def bot_input
    return nil if me?
    input
  end

  def me?
    @command.downcase == "/me"
  end
end
