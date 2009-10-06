
require 'base_bot'

$BOTDIR = File.dirname(__FILE__)
# record the pid
File.open(File.join($BOTDIR, 'pids','tracker.pid'),'w') {|f| f.write(Process.pid) }

class ActivityLogging < BaseBot
    
  def initialize(world_name)
    super(world_name)
  end
  
  def log_avatar_add
    set_event_handler :AW_EVENT_AVATAR_ADD, Proc.new {
      a = attributes_for(:AW_EVENT_AVATAR_ADD)
      info "ENTER | #{a[:AW_AVATAR_NAME]} | #{a[:AW_AVATAR_SESSION]}" +
          " | #{a[:AW_AVATAR_X]} | #{a[:AW_AVATAR_Y]} | #{a[:AW_AVATAR_Z]}" +
          " | #{a[:AW_AVATAR_YAW]}"
    }
  end
  
  def log_chat
    set_event_handler :AW_EVENT_CHAT, Proc.new {
      a = attributes_for(:AW_EVENT_CHAT)
      info "CHAT | #{a[:AW_AVATAR_NAME]} | #{a[:AW_CHAT_MESSAGE]}"
    }
  end
  
  def log_avatar_change
    set_event_handler :AW_EVENT_AVATAR_CHANGE, Proc.new {
      a = attributes_for(:AW_EVENT_AVATAR_CHANGE)
      info "MOVED | #{a[:AW_AVATAR_NAME]} | #{a[:AW_AVATAR_SESSION]}" +
        " | #{a[:AW_AVATAR_X]} | #{a[:AW_AVATAR_Y]} | #{a[:AW_AVATAR_Z]}" +
        " | #{a[:AW_AVATAR_YAW]}"
    }
  end

  def log_avatar_delete
    set_event_handler :AW_EVENT_AVATAR_DELETE, Proc.new {
      a = attributes_for(:AW_EVENT_AVATAR_DELETE)
      info "LEFT | #{a[:AW_AVATAR_NAME]} | #{a[:AW_AVATAR_SESSION]}"
    }
  end

  def log_avatar_click
    set_event_handler :AW_EVENT_AVATAR_CLICK, Proc.new {
      a = attributes_for(:AW_EVENT_AVATAR_CLICK)
      info "AVATAR_CLICK | #{a[:AW_AVATAR_NAME]} | #{a[:AW_CLICKED_NAME]}"
    }
  end
  
  def log_object_click
    set_event_handler :AW_EVENT_OBJECT_CLICK, Proc.new {
      a = attributes_for(:AW_EVENT_OBJECT_CLICK)
      info "OBJECT_CLICK | #{a[:AW_AVATAR_NAME]} | #{a[:AW_CELL_X]} | #{a[:AW_CELL_Z]}" +
        " | #{a[:AW_OBJECT_ID]} | #{a[:AW_OBJECT_TYPE]} | #{a[:AW_OBJECT_X]} | #{a[:AW_OBJECT_Y]}" +
        " | #{a[:AW_OBJECT_Z]} | #{a[:AW_OBJECT_MODEL]} | #{a[:AW_OBJECT_DESCRIPTION]} | #{a[:AW_OBJECT_ACTION]}"
    }
  end

  def log_url_click
    set_event_handler :AW_EVENT_URL_CLICK, Proc.new {
      a = attributes_for(:AW_EVENT_URL_CLICK)
      info "URL_CLICK | #{a[:AW_AVATAR_NAME]} | #{a[:AW_AVATAR_SESSION]} | #{a[:AW_URL_NAME]}"
    }
  end

  def self.for_world(world_name)
    bot = super( world_name )
    bot.log_avatar_add
    bot.log_chat
    bot.log_avatar_change
    bot.log_avatar_delete
    bot.log_avatar_click
    bot.log_object_click
    bot.log_url_click
    bot
  end
  
  def self.do_work
    @@bots[:instances].each do |bot|
      bot.set_self_as_instance
    end
  end
  
end

def run(options, logger)
  ActivityLogging.configure(options, logger)
  worlds = YAML.load_file('worlds.yml')
  ActivityLogging.start_worlds_by_batch( ActivityLogging.config_worlds.collect {|world_group| worlds[world_group]}.flatten )
  while 0 == ActivityLogging.wait(10000)
    #put non-event work here
  end
rescue => ex
  $ActivityLogger.fatal("#{ex.class} : #{ex.message}\n#{ex.backtrace.join("\n")}")
end

config = YAML.load_file("bots_config.yml")["tracker"]
$ActivityLogger = BotLogger.new(config)
run(config, $ActivityLogger)

