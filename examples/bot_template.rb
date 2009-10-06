# This is an example template
#
#

require 'base_bot'

$BOTDIR = File.dirname(__FILE__)
# record the pid
File.open(File.join($BOTDIR, 'pids','BOT.pid'),'w') {|f| f.write(Process.pid) }

class BOT < BaseBot
  
  def initialize(world_name)
    super(world_name)
    
  end
  
  def log_avatar_add
    set_event_handler :AW_EVENT_AVATAR_ADD, Proc.new {
      a = attributes_for(:AW_EVENT_AVATAR_ADD)
      
    }
  end

  # An example for how to setup 
  def handle_hud_callback_result
    set_callback_handler :AW_CALLBACK_HUD_RESULT, Proc.new {|rc|
      a = attributes_for(:AW_CALLBACK_HUD_RESULT)
      debug "HUD_RESULT | #{rc_sym(rc)} | #{a[:AW_HUD_ELEMENT_SESSION]} | #{a[:AW_HUD_ELEMENT_ID]}"
    }
  end
  
  # called by start_worlds_by_batch
  def self.for_world(world_name)
    bot = super( world_name )
    # register callbacks
    
    bot
  end
  
  def self.do_work
    @@bots[:instances].each do |bot|
      bot.set_self_as_instance
    end
  end
end

def run(options, logger)
  BOT.configure(options, logger)
  worlds = YAML.load_file('worlds.yml')
  BOT.start_worlds_by_batch( BOT.config_worlds.collect {|world_group| worlds[world_group]}.flatten )
  while 0 == BOT.wait(1000)
    #put non-event work here
  end
rescue => ex
  $BOTLogger.fatal("#{ex.class} : #{ex.message}\n#{ex.backtrace.join("\n")}")
end

config = YAML.load_file("bots_config.yml")["BOT"]
$BOTLogger = BotLogger.new(config)
run(config, $BOTLogger)
