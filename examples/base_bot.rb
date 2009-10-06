require 'rubygems'
require 'yaml'
require 'bot_logger'
require 'activeworlds_ffi'

class BaseBot
  extend ActiveworldsFFI
  include ActiveworldsFFI

  attr_accessor :params
  def self.bots
    @@bots
  end
  def self.config_worlds
    @@config[:world_groups]
  end
  def self.wait(msec)
    aw_wait msec
  end

  # Expects a yaml file that defines the values for
  # 
  def self.configure(config_options,logger=nil)
    @@config = config_options
    @@configured = true
    @@log = logger || BotLogger.new({:appname=>'base_bot'})
    aw_init AW_BUILD
  end
  
  def self.class_setup
    @@init_run = true
    @@bots ||= {:instances =>[], :events =>{}, :callbacks =>{}}
    set_disconnect_handlers
    set_create_handlers
  end
  
  def login(name, owner_id, privilege_pass, application_name)
    aw_string_set(AW_LOGIN_NAME, name)
    aw_int_set(AW_LOGIN_OWNER, owner_id)
    aw_string_set(AW_LOGIN_PRIVILEGE_PASSWORD, privilege_pass)
    aw_string_set(AW_LOGIN_APPLICATION, application_name) if ! application_name.empty?
    aw_login
  end

  def enter(world_name)
    @params[:world_name] = world_name
    aw_enter(world_name)
  end

  def delete
    warn "DELETING INSTANCE FOR #{@params[:world_name]}"
    set_self_as_instance
    aw_destroy 
    @@bots[:instances].delete self
    @bot_ptr = nil
  end
  
  def self.set_disconnect_handlers
    set_event_handler :AW_EVENT_WORLD_DISCONNECT, Proc.new {
      bot = current_instance
      unless bot.nil?
        a = bot.attributes_for(:AW_EVENT_WORLD_DISCONNECT)
        bot.warn "AW_EVENT_WORLD_DISCONNECT | #{rc_msg(a[:AW_DISCONNECT_REASON])}"
        bot.params[:connection] = :RC_CONNECTION_LOST
      end
    }
    set_event_handler :AW_EVENT_UNIVERSE_DISCONNECT, Proc.new {
      bot = current_instance
      unless bot.nil?
        a = bot.attributes_for(:AW_EVENT_UNIVERSE_DISCONNECT)
        bot.warn "AW_EVENT_UNIVERSE_DISCONNECT | #{rc_msg(a[:AW_DISCONNECT_REASON])}"
        bot.params[:connection] = :RC_CONNECTION_LOST
      end
    }
  end

  def self.set_create_handlers
    set_callback_handler :AW_CALLBACK_CREATE, Proc.new {|rc|
      bot = current_instance
      unless bot.nil?
        a = bot.attributes_for(:AW_CALLBACK_CREATE)
        bot.info "AW_CALLBACK_CREATE | #{rc_sym rc} | #{bot.params[:world_name]}"
        rc = rc_sym(rc)
        case rc
        when :RC_SUCCESS
          aw_bool_set(AW_ENTER_GLOBAL, @@config[:global_bot])
          bot.login(@@config[:login_name], @@config[:bot_owner_id], @@config[:password], @@config[:application_name])
        else
          bot.warn "CREATE BOT FAILURE | Failed to create the #{@@config[:application_name]} bot: #{rc} : #{rc_msg rc}"
        end
      end
    }
    set_callback_handler :AW_CALLBACK_LOGIN, Proc.new {|rc|
      bot = current_instance
      unless bot.nil?
        a = bot.attributes_for(:AW_CALLBACK_LOGIN)
        rc = rc_sym(rc)
        case rc
        when :RC_SUCCESS
          bot.info "AW_CALLBACK_LOGIN | #{rc}"
          bot.enter(bot.params[:world_name])
        else
          bot.warn "AW_CALLBACK_LOGIN | #{rc} | #{rc_msg(rc)}"
          bot.delete
        end
      end
    }
    set_callback_handler :AW_CALLBACK_ENTER, Proc.new {|rc|
      bot = current_instance
      unless bot.nil?
        a = bot.attributes_for(:AW_CALLBACK_ENTER)
        rc = rc_sym(rc)
        bot.params[:connection] = rc
        bot.info "AW_CALLBACK_ENTER | #{rc} | #{a[:AW_WORLD_NAME]}"
        case rc
        when :RC_NO_SUCH_WORLD
          bot.delete
        end
      end
    }
  end  

  def debug(str); @@log.debug "#{@params[:world_name]} | #{str}" ; end
  def info(str);  @@log.info  "#{@params[:world_name]} | #{str}" ; end
  def warn(str);  @@log.warn  "#{@params[:world_name]} | #{str}" ; end
  def error(str); @@log.error "#{@params[:world_name]} | #{str}" ; end
  def fatal(str); @@log.fatal "#{@params[:world_name]} | #{str}" ; end
  def logger(); @@log ; end
  def self.logger; @@log ; end
  
  def initialize(world_name)
    unless @@configured
      raise RuntimeError.new( "You must #{self.class}.config(config_filename) before creating any instances!!!")
    end
    @@init_run ||= false
    unless @@init_run
      self.class.class_setup
    end
    @bot_ptr = FFI::MemoryPointer.new(:pointer)
    @params = {:world_name => world_name, :bot_ptr => @bot_ptr, :events => {}, :callbacks => {}}
    @@bots[:instances].push self
    aw_create( @@config[:host], @@config[:port], @bot_ptr)
    info "initialized new bot for #{world_name}"
  end

  def self.for_world(world_name)
    bot = new(world_name)
    bot
  end

  def self.start_worlds_by_batch(world_stack)
    while !world_stack.empty?
      startup_batch = world_stack.slice!(0,15)
      startup_batch.each do |world|
        for_world(world)
      end
      wait(200)
    end
  end
  
  def self.current_instance
    mem_ptr = aw_instance
    @@bots[:instances].detect do |bot| 
      bot.params[:bot_ptr].read_pointer.address  == mem_ptr.address
    end
  end
  
  def current_instance
    self.class.current_instance
  end
  
  def bot_c_pointer
    params[:bot_ptr].read_pointer
  end
  
  def set_instance(target_bot)
    aw_instance_set target_bot.bot_c_pointer
  end
  
  def set_self_as_instance
    aw_instance_set bot_c_pointer
  end
  
  def self.set_callback_handler(callback, handler)
    @@bots[:callbacks][callback] = handler
    aw_callback_set AW_CALLBACK_ENUM[callback], @@bots[:callbacks][callback]
  end
  
  def set_callback_handler(callback, handler)
    set_self_as_instance
    @@bots[:callbacks][callback] = handler
    aw_instance_callback_set AW_CALLBACK_ENUM[callback], @@bots[:callbacks][callback]
  end
  
  def self.set_event_handler(event, handler)
    @@bots[:events][event] = handler
    aw_event_set AW_EVENT_ATTRIBUTE_ENUM[event], @@bots[:events][event]
  end

  #
  # This sets a bot instance handler as opposed to the general callback
  # that can be set with the class method
  #
  #   def log_avatar_add
  #     set_event_handler :AW_EVENT_AVATAR_ADD, Proc.new {
  #       bot = self.class.current_instance
  #       if bot.nil?
  #         bot.warn "couldn't find current bot"
  #       else
  #         a = bot.attributes_for(:AW_EVENT_AVATAR_ADD)
  #         bot.info "ENTER | #{a[:AW_AVATAR_NAME]} | #{a[:AW_AVATAR_SESSION]}" +
  #           " | #{a[:AW_AVATAR_X]} | #{a[:AW_AVATAR_Y]} | #{a[:AW_AVATAR_Z]}" +
  #           " | #{a[:AW_AVATAR_YAW]}"
  #       end
  #     }
  #   end
  def set_event_handler(event, handler)
    set_self_as_instance
    @params[:events][event] = handler
    aw_instance_event_set AW_EVENT_ATTRIBUTE_ENUM[event], @params[:events][event]
  end

  def attributes_for(callback_or_event)
    aw_params = {}
    unless @@attrs_available_to[callback_or_event].nil?
      @@attrs_available_to[callback_or_event].each do |aw_attr|
        aw_params[aw_attr] = aw_attribute_value(aw_attr)
      end
    end
    aw_params
  end
  
  def aw_attribute_value(attribute)
    attribute_type = AwSDK_ATTRIBUTE_TYPE_MAP[attribute] 
    attribute_const = AW_ATTRIBUTE_ENUM[attribute]
    case attribute_type
    when :bool
      aw_bool(attribute_const)
    when :float
      aw_float(attribute_const)
    when :int
      aw_int(attribute_const)
    when :string
      aw_string(attribute_const)
    when :data
      len = FFI::Buffer.new(:int)
      data = aw_data(attribute_const, len)
      if 0 < len.get_uint(0)
        data.get_bytes(0,len.get_uint(0)) 
      else
        ""
      end
    end
  end

  # nil arguments mean that the corresponding attribute isn't set/changed
  def state_change(options)
    aw_int_set(AW_MY_X, x)             unless options[:x].nil?
    aw_int_set(AW_MY_Y, y)             unless options[:y].nil?
    aw_int_set(AW_MY_Z, z)             unless options[:z].nil?
    aw_int_set(AW_MY_YAW, yaw)         unless options[:yaw].nil?
    aw_int_set(AW_MY_TYPE, type)       unless options[:type].nil?
    aw_int_set(AW_MY_GESTURE, gesture) unless options[:gesture].nil?
    aw_int_set(AW_MY_PITCH, pitch)     unless options[:pitch].nil?
    aw_int_set(AW_MY_STATE, state)     unless options[:state].nil?
    aw_state_change
  end

  # Wraps aw_console_message. Options are :red, :blue, :green, :bold, :italics
  def console_message(session_id, message, options={})
    aw_int_set(AW_CONSOLE_RED, options[:red] || 0)
    aw_int_set(AW_CONSOLE_BLUE, options[:blue] || 0)
    aw_int_set(AW_CONSOLE_GREEN, options[:green] || 0)
    aw_bool_set(AW_CONSOLE_BOLD, options[:bold] || false)
    aw_bool_set(AW_CONSOLE_ITALICS, options[:italics] || false)
    aw_string_set(AW_CONSOLE_MESSAGE, message)
    aw_console_message(session_id)
  end

  # Wraps aw_teleport. Options are :world, :x, :y, :z, :yaw, :warp
  def teleport(session_id, options={}) 
    aw_string_set(AW_TELEPORT_WORLD, options[:world] || "")
    aw_int_set(AW_TELEPORT_X, options[:x] || 0)
    aw_int_set(AW_TELEPORT_Y, options[:y] || 0)
    aw_int_set(AW_TELEPORT_Z, options[:z] || 0)
    aw_int_set(AW_TELEPORT_YAW, options[:yaw] || 0)
    aw_bool_set(AW_TELEPORT_WARP, options[:warp] || false)
    aw_teleport(session_id)
  end

  def world_object_change(object_update)
    aw_int_set(AW_OBJECT_ID, object_update[:AW_OBJECT_ID])
    aw_int_set(AW_OBJECT_TYPE, object_update[:AW_OBJECT_TYPE] || AW_OBJECT_TYPE_V3)
    aw_string_set(AW_OBJECT_DESCRIPTION, object_update[:AW_OBJECT_DESCRIPTION])
    aw_string_set(AW_OBJECT_ACTION, object_update[:AW_OBJECT_ACTION])
    aw_string_set(AW_OBJECT_MODEL, object_update[:AW_OBJECT_MODEL])
    aw_int_set(AW_OBJECT_OLD_NUMBER, 0)
    aw_int_set(AW_OBJECT_OLD_X, 0)
    aw_int_set(AW_OBJECT_OLD_Z, 0)
    aw_int_set(AW_OBJECT_X, object_update[:AW_OBJECT_X])
    aw_int_set(AW_OBJECT_Y, object_update[:AW_OBJECT_Y])
    aw_int_set(AW_OBJECT_Z, object_update[:AW_OBJECT_Z])
    aw_int_set(AW_OBJECT_YAW, object_update[:AW_OBJECT_YAW])
    aw_int_set(AW_OBJECT_TILT, object_update[:AW_OBJECT_TILT])
    aw_int_set(AW_OBJECT_ROLL, object_update[:AW_OBJECT_ROLL])
    aw_int_set(AW_OBJECT_OWNER, object_update[:AW_OBJECT_OWNER])
    aw_object_change
  end

  def url_send(session, url, target_window=nil)
    aw_url_send(session, url, target_window)
  end

  def add_world_ejection(citizen_id, session, expiration=0, comment="Account disabled")
    aw_int_set( AW_EJECTION_TYPE, AW_EJECT_BY_CITIZEN )
    aw_int_set(AW_EJECTION_ADDRESS, citizen_id)
    aw_int_set(AW_EJECTION_EXPIRATION_TIME, expiration.to_i)
    aw_string_set(AW_EJECTION_COMMENT, comment)
    rc = rc_sym(aw_world_ejection_add)
    if :RC_SUCCESS == rc
      world_eject session
    end
    rc
  end

  # eject session for 1 second to force out of world
  def world_eject(session,time=1)
    aw_int_set AW_EJECT_SESSION, session
    aw_int_set AW_EJECT_DURATION, time
    aw_world_eject
  end
  
  def hud_create(options={})
    # debug("CREATING HUD ELEMENT WITH | #{options.sort.inspect}")
    aw_int_set(AW_HUD_ELEMENT_TYPE,      options[:AW_HUD_ELEMENT_TYPE])
    aw_string_set(AW_HUD_ELEMENT_TEXT,   options[:AW_HUD_ELEMENT_TEXT])
    aw_float_set(AW_HUD_ELEMENT_OPACITY, options[:AW_HUD_ELEMENT_OPACITY])
    aw_int_set(AW_HUD_ELEMENT_ID,        options[:AW_HUD_ELEMENT_ID])
    aw_int_set(AW_HUD_ELEMENT_SESSION,   options[:AW_HUD_ELEMENT_SESSION])
    aw_int_set(AW_HUD_ELEMENT_ORIGIN,    options[:AW_HUD_ELEMENT_ORIGIN])
    aw_int_set(AW_HUD_ELEMENT_X,         options[:AW_HUD_ELEMENT_X])
    aw_int_set(AW_HUD_ELEMENT_Y,         options[:AW_HUD_ELEMENT_Y])
    aw_int_set(AW_HUD_ELEMENT_Z,         options[:AW_HUD_ELEMENT_Z])
    aw_int_set(AW_HUD_ELEMENT_FLAGS,     options[:AW_HUD_ELEMENT_FLAGS])
    aw_int_set(AW_HUD_ELEMENT_COLOR,     options[:AW_HUD_ELEMENT_COLOR])
    aw_int_set(AW_HUD_ELEMENT_SIZE_X,    options[:AW_HUD_ELEMENT_SIZE_X])
    aw_int_set(AW_HUD_ELEMENT_SIZE_Y,    options[:AW_HUD_ELEMENT_SIZE_Y])
    aw_int_set(AW_HUD_ELEMENT_TEXTURE_OFFSET_X,    options[:AW_HUD_ELEMENT_TEXTURE_OFFSET_X])
    aw_int_set(AW_HUD_ELEMENT_TEXTURE_OFFSET_Y,    options[:AW_HUD_ELEMENT_TEXTURE_OFFSET_Y])
    rc_sym(aw_hud_create)
  end
  
  # This class allows is for the generation of RubyActiveworld specific errors
  class AwSDKError < RuntimeError; end

  module AwSDKSupport
    # call-seq:
    #   rc_sym ruby_aw_init =>  :RC_SUCCESS
    #   
    # This returns the symbol corresponding to the return code name
    def rc_sym(rc_int)
      RETURN_CODE_MAP[rc_int][:error_symbol]
    end

    # call-seq:
    #   rc_msg ruby_aw_init => "Success: Return value from an asynchronous call..."
    #   rc_msg some_failing_call => "This call failed due to ..." 
    #
    # This looks up return code's corresponding explanation.
    def rc_msg(rc_int_or_sym)
      (rc_int_or_sym.is_a?(Symbol) ? RETURN_CODE_SYMBOL_MAP : RETURN_CODE_MAP)[rc_int_or_sym][:error_explanation]
    end

    def raise_on_error(rc_int)
      if :RC_SUCCESS != rc_sym(rc_int)
        throw AwSDKError.new( "#{rc_int} : #{rc_msg(rc_int)}")
      end
    end
  
    def rc_int(rc_sym)
      RETURN_CODE_SYMBOL_MAP[rc_sym][:rc]
    end

    AwSDK_ATTRIBUTE_TYPE_MAP = { 
      :AW_AVATAR_LOCK => :bool,
      :AW_CELL_COMBINE => :bool,
      :AW_CITIZEN_BETA => :bool,
      :AW_CITIZEN_CAV_ENABLED => :bool,
      :AW_CITIZEN_ENABLED => :bool,
      :AW_CITIZEN_PAV_ENABLED => :bool,
      :AW_CITIZEN_TRIAL => :bool,
      :AW_CONSOLE_BOLD => :bool,
      :AW_CONSOLE_ITALICS => :bool,
      :AW_ENTER_GLOBAL => :bool,
      :AW_LICENSE_ALLOW_TOURISTS => :bool,
      :AW_LICENSE_HIDDEN => :bool,
      :AW_LICENSE_PLUGINS => :bool,
      :AW_LICENSE_VOIP => :bool,
      :AW_QUERY_COMPLETE => :bool,
      :AW_SERVER_ENABLED => :bool,
      :AW_SERVER_MORE => :bool,
      :AW_TELEPORT_WARP => :bool,
      :AW_TERRAIN_COMPLETE => :bool,
      :AW_URL_TARGET_3D => :bool,
      :AW_USERLIST_MORE => :bool,
      :AW_WORLDLIST_MORE => :bool,
      :AW_CAV_DEFINITION => :data,
      :AW_OBJECT_DATA => :data,
      :AW_TERRAIN_NODE_HEIGHTS => :data,
      :AW_TERRAIN_NODE_TEXTURES => :data,
      :AW_HUD_ELEMENT_OPACITY => :float,
      :AW_ATTRIB_SENDER_SESSION => :int,
      :AW_AVATAR_ADDRESS => :int,
      :AW_AVATAR_ANGLE => :int,
      :AW_AVATAR_CITIZEN => :int,
      :AW_AVATAR_DISTANCE => :int,
      :AW_AVATAR_FLAGS => :int,
      :AW_AVATAR_GESTURE => :int,
      :AW_AVATAR_PITCH => :int,
      :AW_AVATAR_PITCH_DELTA => :int,
      :AW_AVATAR_PRIVILEGE => :int,
      :AW_AVATAR_SESSION => :int,
      :AW_AVATAR_STATE => :int,
      :AW_AVATAR_TYPE => :int,
      :AW_AVATAR_VERSION => :int,
      :AW_AVATAR_WORLD_INSTANCE => :int,
      :AW_AVATAR_X => :int,
      :AW_AVATAR_Y => :int,
      :AW_AVATAR_Y_DELTA => :int,
      :AW_AVATAR_YAW => :int,
      :AW_AVATAR_YAW_DELTA => :int,
      :AW_AVATAR_Z => :int,
      :AW_BOTGRAM_FROM => :int,
      :AW_BOTGRAM_TO => :int,
      :AW_BOTGRAM_TYPE => :int,
      :AW_BOTMENU_FROM_SESSION => :int,
      :AW_BOTMENU_TO_SESSION => :int,
      :AW_CAMERA_LOCATION_SESSION => :int,
      :AW_CAMERA_LOCATION_TYPE => :int,
      :AW_CAMERA_TARGET_SESSION => :int,
      :AW_CAMERA_TARGET_TYPE => :int,
      :AW_CAV_CITIZEN => :int,
      :AW_CAV_SESSION => :int,
      :AW_CELL_ITERATOR => :int,
      :AW_CELL_SEQUENCE => :int,
      :AW_CELL_SIZE => :int,
      :AW_CELL_X => :int,
      :AW_CELL_Z => :int,
      :AW_CHAT_SESSION => :int,
      :AW_CHAT_TYPE => :int,
      :AW_CITIZEN_BOT_LIMIT => :int,
      :AW_CITIZEN_EXPIRATION_TIME => :int,
      :AW_CITIZEN_IMMIGRATION_TIME => :int,
      :AW_CITIZEN_LAST_ADDRESS => :int,
      :AW_CITIZEN_LAST_LOGIN => :int,
      :AW_CITIZEN_NUMBER => :int,
      :AW_CITIZEN_PRIVACY => :int,
      :AW_CITIZEN_TIME_LEFT => :int,
      :AW_CITIZEN_TOTAL_TIME => :int,
      :AW_CLICKED_SESSION => :int,
      :AW_CONSOLE_BLUE => :int,
      :AW_CONSOLE_GREEN => :int,
      :AW_CONSOLE_RED => :int,
      :AW_DISCONNECT_REASON => :int,
      :AW_EJECT_DURATION => :int,
      :AW_EJECT_SESSION => :int,
      :AW_EJECTION_ADDRESS => :int,
      :AW_EJECTION_CREATION_TIME => :int,
      :AW_EJECTION_EXPIRATION_TIME => :int,
      :AW_EJECTION_TYPE => :int,
      :AW_ENTITY_FLAGS => :int,
      :AW_ENTITY_ID => :int,
      :AW_ENTITY_MODEL_NUM => :int,
      :AW_ENTITY_OWNER_CITIZEN => :int,
      :AW_ENTITY_OWNER_SESSION => :int,
      :AW_ENTITY_PITCH => :int,
      :AW_ENTITY_ROLL => :int,
      :AW_ENTITY_STATE => :int,
      :AW_ENTITY_TYPE => :int,
      :AW_ENTITY_X => :int,
      :AW_ENTITY_Y => :int,
      :AW_ENTITY_YAW => :int,
      :AW_ENTITY_Z => :int,
      :AW_HUD_ELEMENT_CLICK_X => :int,
      :AW_HUD_ELEMENT_CLICK_Y => :int,
      :AW_HUD_ELEMENT_CLICK_Z => :int,
      :AW_HUD_ELEMENT_COLOR => :int,
      :AW_HUD_ELEMENT_FLAGS => :int,
      :AW_HUD_ELEMENT_ID => :int,
      :AW_HUD_ELEMENT_ORIGIN => :int,
      :AW_HUD_ELEMENT_SESSION => :int,
      :AW_HUD_ELEMENT_SIZE_X => :int,
      :AW_HUD_ELEMENT_SIZE_Y => :int,
      :AW_HUD_ELEMENT_SIZE_Z => :int,
      :AW_HUD_ELEMENT_TEXTURE_OFFSET_X => :int,
      :AW_HUD_ELEMENT_TEXTURE_OFFSET_Y => :int,
      :AW_HUD_ELEMENT_TYPE => :int,
      :AW_HUD_ELEMENT_X => :int,
      :AW_HUD_ELEMENT_Y => :int,
      :AW_HUD_ELEMENT_Z => :int,
      :AW_LICENSE_CREATION_TIME => :int,
      :AW_LICENSE_EXPIRATION_TIME => :int,
      :AW_LICENSE_LAST_ADDRESS => :int,
      :AW_LICENSE_LAST_START => :int,
      :AW_LICENSE_RANGE => :int,
      :AW_LICENSE_USERS => :int,
      :AW_LOGIN_OWNER => :int,
      :AW_MY_GESTURE => :int,
      :AW_MY_PITCH => :int,
      :AW_MY_STATE => :int,
      :AW_MY_TYPE => :int,
      :AW_MY_X => :int,
      :AW_MY_Y => :int,
      :AW_MY_YAW => :int,
      :AW_MY_Z => :int,
      :AW_OBJECT_BUILD_TIMESTAMP => :int,
      :AW_OBJECT_CALLBACK_REFERENCE => :int,
      :AW_OBJECT_DATA => :data,
      :AW_OBJECT_ID => :int,
      :AW_OBJECT_NUMBER => :int,
      :AW_OBJECT_OLD_NUMBER => :int,
      :AW_OBJECT_OLD_X => :int,
      :AW_OBJECT_OLD_Z => :int,
      :AW_OBJECT_OWNER => :int,
      :AW_OBJECT_ROLL => :int,
      :AW_OBJECT_SESSION => :int,
      :AW_OBJECT_SYNC => :int,
      :AW_OBJECT_TILT => :int,
      :AW_OBJECT_TYPE => :int,
      :AW_OBJECT_X => :int,
      :AW_OBJECT_Y => :int,
      :AW_OBJECT_YAW => :int,
      :AW_OBJECT_Z => :int,
      :AW_SERVER_BUILD => :int,
      :AW_SERVER_EXPIRATION => :int,
      :AW_SERVER_ID => :int,
      :AW_SERVER_INSTANCE => :int,
      :AW_SERVER_MAX_USERS => :int,
      :AW_SERVER_OBJECTS => :int,
      :AW_SERVER_SIZE => :int,
      :AW_SERVER_START_RC => :int,
      :AW_SERVER_STATE => :int,
      :AW_SERVER_TERRAIN_NODES => :int,
      :AW_SERVER_USERS => :int,
      :AW_TELEPORT_X => :int,
      :AW_TELEPORT_Y => :int,
      :AW_TELEPORT_YAW => :int,
      :AW_TELEPORT_Z => :int,
      :AW_TERRAIN_NODE_HEIGHT_COUNT => :int,
      :AW_TERRAIN_NODE_SIZE => :int,
      :AW_TERRAIN_NODE_TEXTURE_COUNT => :int,
      :AW_TERRAIN_NODE_X => :int,
      :AW_TERRAIN_NODE_Z => :int,
      :AW_TERRAIN_PAGE_X => :int,
      :AW_TERRAIN_PAGE_Z => :int,
      :AW_TERRAIN_SEQUENCE => :int,
      :AW_TERRAIN_VERSION_NEEDED => :int,
      :AW_TERRAIN_X => :int,
      :AW_TERRAIN_Z => :int,
      :AW_TOOLBAR_ID => :int,
      :AW_TOOLBAR_SESSION => :int,
      :AW_USERLIST_ADDRESS => :int,
      :AW_USERLIST_CITIZEN => :int,
      :AW_USERLIST_ID => :int,
      :AW_USERLIST_PRIVILEGE => :int,
      :AW_USERLIST_STATE => :int,
      :AW_WORLDLIST_RATING => :int,
      :AW_WORLDLIST_STATUS => :int,
      :AW_WORLDLIST_USERS => :int,
      :AW_AVATAR_NAME => :string,
      :AW_BOTGRAM_FROM_NAME => :string,
      :AW_BOTMENU_FROM_NAME => :string,
      :AW_CAMERA_LOCATION_OBJECT => :string,
      :AW_CAMERA_TARGET_OBJECT => :string,
      :AW_CHAT_MESSAGE => :string,
      :AW_CITIZEN_COMMENT => :string,
      :AW_CITIZEN_EMAIL => :string,
      :AW_CITIZEN_NAME => :string,
      :AW_CITIZEN_PASSWORD => :string,
      :AW_CITIZEN_PRIVILEGE_PASSWORD => :string,
      :AW_CITIZEN_URL => :string,
      :AW_CLICKED_NAME => :string,
      :AW_CONSOLE_MESSAGE => :string,
      :AW_EJECTION_COMMENT => :string,
      :AW_HUD_ELEMENT_TEXT => :string,
      :AW_LICENSE_COMMENT => :string,
      :AW_LICENSE_EMAIL => :string,
      :AW_LICENSE_NAME => :string,
      :AW_LICENSE_PASSWORD => :string,
      :AW_LOGIN_APPLICATION => :string,
      :AW_LOGIN_NAME => :string,
      :AW_LOGIN_PASSWORD => :string,
      :AW_LOGIN_PRIVILEGE_NAME => :string,
      :AW_LOGIN_PRIVILEGE_PASSWORD => :string,
      :AW_OBJECT_ACTION => :string,
      :AW_OBJECT_DESCRIPTION => :string,
      :AW_OBJECT_MODEL => :string,
      :AW_PLUGIN_STRING => :string,
      :AW_SERVER_CARETAKERS => :string,
      :AW_SERVER_NAME => :string,
      :AW_SERVER_PASSWORD => :string,
      :AW_SERVER_REGISTRY => :string,
      :AW_SOUND_NAME => :string,
      :AW_TELEPORT_WORLD => :string,
      :AW_URL_POST => :string,
      :AW_URL_TARGET => :string,
      :AW_USERLIST_EMAIL => :string,
      :AW_USERLIST_NAME => :string,
      :AW_USERLIST_WORLD => :string,
      :AW_WORLDLIST_NAME => :string,
      :AW_BOTGRAM_TEXT => :string,
      :AW_BOTMENU_ANSWER => :string,
      :AW_BOTMENU_QUESTION => :string,
      :AW_URL_NAME => :string,
      :AW_UNIVERSE_ALLOW_BOTS_CAV => :bool,
      :AW_UNIVERSE_ALLOW_TOURISTS => :bool,
      :AW_UNIVERSE_ALLOW_TOURISTS_CAV => :bool,
      :AW_UNIVERSE_CITIZEN_CHANGES_ALLOWED => :bool,
      :AW_UNIVERSE_REGISTRATION_REQUIRED => :bool,
      :AW_UNIVERSE_USER_LIST_ENABLED => :bool,
      :AW_UNIVERSE_OBJECT_PASSWORD => :data,
      :AW_UNIVERSE_BROWSER_BETA => :int,
      :AW_UNIVERSE_BROWSER_MINIMUM => :int,
      :AW_UNIVERSE_BROWSER_RELEASE => :int,
      :AW_UNIVERSE_BROWSER_RELEASE_22 => :int	 ,
      :AW_UNIVERSE_BUILD_NUMBER => :int,
      :AW_UNIVERSE_OBJECT_REFRESH => :int,
      :AW_UNIVERSE_REGISTER_METHOD => :int,
      :AW_UNIVERSE_TIME => :int,
      :AW_UNIVERSE_WORLD_BETA => :int,
      :AW_UNIVERSE_WORLD_MINIMUM => :int,
      :AW_UNIVERSE_WORLD_RELEASE => :int,
      :AW_UNIVERSE_ANNUAL_CHARGE => :string,
      :AW_UNIVERSE_CAV_PATH => :string,
      :AW_UNIVERSE_CAV_PATH2 => :string,
      :AW_UNIVERSE_MONTHLY_CHARGE => :string,
      :AW_UNIVERSE_NAME => :string,
      :AW_UNIVERSE_NOTEPAD_URL => :string,
      :AW_UNIVERSE_SEARCH_URL => :string,
      :AW_UNIVERSE_WELCOME_MESSAGE => :string,
      :AW_UNIVERSE_WORLD_START => :string,
      :AW_WORLD_ALLOW_3_AXIS_ROTATION => :bool,
      :AW_WORLD_ALLOW_AVATAR_COLLISION => :bool,
      :AW_WORLD_ALLOW_CITIZEN_WHISPER => :bool,
      :AW_WORLD_ALLOW_FLYING => :bool,
      :AW_WORLD_ALLOW_OBJECT_SELECT => :bool,
      :AW_WORLD_ALLOW_PASSTHRU => :bool,
      :AW_WORLD_ALLOW_TELEPORT => :bool,
      :AW_WORLD_ALLOW_TOURIST_BUILD => :bool,
      :AW_WORLD_ALLOW_TOURIST_WHISPER => :bool,
      :AW_WORLD_ALWAYS_SHOW_NAMES => :bool,
      :AW_WORLD_AMBIENT_LIGHT_BLUE => :int,
      :AW_WORLD_AMBIENT_LIGHT_GREEN => :int,
      :AW_WORLD_AMBIENT_LIGHT_RED => :int,
      :AW_WORLD_AVATAR_REFRESH_RATE => :int,
      :AW_WORLD_BACKDROP => :string,
      :AW_WORLD_BOTMENU_URL => :string,
      :AW_WORLD_BOTS_RIGHT => :string,
      :AW_WORLD_BUILD_CAPABILITY => :bool,
      :AW_WORLD_BUILD_NUMBER => :int,
      :AW_WORLD_BUILD_RIGHT => :string,
      :AW_WORLD_BUOYANCY => :float,
      :AW_WORLD_CAMERA_ZOOM => :float,
      :AW_WORLD_CARETAKER_CAPABILITY => :bool,
      :AW_WORLD_CAV_OBJECT_PASSWORD => :string,
      :AW_WORLD_CAV_OBJECT_PATH => :string,
      :AW_WORLD_CAV_OBJECT_REFRESH => :int,
      :AW_WORLD_CELL_LIMIT => :int,
      :AW_WORLD_CHAT_DISABLE_URL_CLICKS => :bool,
      :AW_WORLD_CLOUDS_LAYER1_MASK => :string,
      :AW_WORLD_CLOUDS_LAYER1_OPACITY => :int,
      :AW_WORLD_CLOUDS_LAYER1_SPEED_X => :float,
      :AW_WORLD_CLOUDS_LAYER1_SPEED_Z => :float,
      :AW_WORLD_CLOUDS_LAYER1_TEXTURE => :string,
      :AW_WORLD_CLOUDS_LAYER1_TILE => :float,
      :AW_WORLD_CLOUDS_LAYER2_MASK => :string,
      :AW_WORLD_CLOUDS_LAYER2_OPACITY => :int,
      :AW_WORLD_CLOUDS_LAYER2_SPEED_X => :float,
      :AW_WORLD_CLOUDS_LAYER2_SPEED_Z => :float,
      :AW_WORLD_CLOUDS_LAYER2_TEXTURE => :string,
      :AW_WORLD_CLOUDS_LAYER2_TILE => :float,
      :AW_WORLD_CLOUDS_LAYER3_MASK => :string,
      :AW_WORLD_CLOUDS_LAYER3_OPACITY => :int,
      :AW_WORLD_CLOUDS_LAYER3_SPEED_X => :float,
      :AW_WORLD_CLOUDS_LAYER3_SPEED_Z => :float,
      :AW_WORLD_CLOUDS_LAYER3_TEXTURE => :string,
      :AW_WORLD_CLOUDS_LAYER3_TILE => :float,
      :AW_WORLD_CREATION_TIMESTAMP => :int,
      :AW_WORLD_DISABLE_AVATAR_LIST => :bool,
      :AW_WORLD_DISABLE_CHAT => :bool,
      :AW_WORLD_DISABLE_CREATE_URL => :bool,
      :AW_WORLD_DISABLE_MULTIPLE_MEDIA => :bool,
      :AW_WORLD_DISABLE_SHADOWS => :bool,
      :AW_WORLD_EJECT_CAPABILITY => :bool,
      :AW_WORLD_EJECT_RIGHT => :string,
      :AW_WORLD_EMINENT_DOMAIN_CAPABILITY => :bool,
      :AW_WORLD_EMINENT_DOMAIN_RIGHT => :string,
      :AW_WORLD_ENABLE_BUMP_EVENT => :bool,
      :AW_WORLD_ENABLE_CAMERA_COLLISION => :bool,
      :AW_WORLD_ENABLE_CAV => :int,
      :AW_WORLD_ENABLE_PAV => :bool,
      :AW_WORLD_ENABLE_REFERER => :bool,
      :AW_WORLD_ENABLE_SYNC_EVENTS => :bool,
      :AW_WORLD_ENABLE_TERRAIN => :bool,
      :AW_WORLD_ENTER_RIGHT => :string,
      :AW_WORLD_ENTRY_POINT => :string,
      :AW_WORLD_EXPIRATION => :int,
      :AW_WORLD_FOG_BLUE => :int,
      :AW_WORLD_FOG_ENABLE => :bool,
      :AW_WORLD_FOG_GREEN => :int,
      :AW_WORLD_FOG_MAXIMUM => :int,
      :AW_WORLD_FOG_MINIMUM => :int,
      :AW_WORLD_FOG_RED => :int,
      :AW_WORLD_FOG_TINTED => :bool,
      :AW_WORLD_FRICTION => :float,
      :AW_WORLD_GRAVITY => :float,
      :AW_WORLD_GROUND => :string,
      :AW_WORLD_HOME_PAGE => :string,
      :AW_WORLD_KEYWORDS => :string,
      :AW_WORLD_LIGHT_BLUE => :int,
      :AW_WORLD_LIGHT_DRAW_BRIGHT => :bool,
      :AW_WORLD_LIGHT_DRAW_FRONT => :bool,
      :AW_WORLD_LIGHT_DRAW_SIZE => :int,
      :AW_WORLD_LIGHT_GREEN => :int,
      :AW_WORLD_LIGHT_MASK => :string,
      :AW_WORLD_LIGHT_RED => :int,
      :AW_WORLD_LIGHT_SOURCE_COLOR => :int,
      :AW_WORLD_LIGHT_SOURCE_USE_COLOR => :bool,
      :AW_WORLD_LIGHT_TEXTURE => :string,
      :AW_WORLD_LIGHT_X => :float,
      :AW_WORLD_LIGHT_Y => :float,
      :AW_WORLD_LIGHT_Z => :float,
      :AW_WORLD_MAX_LIGHT_RADIUS => :int,
      :AW_WORLD_MAX_USERS => :int,
      :AW_WORLD_MINIMUM_VISIBILITY => :int,
      :AW_WORLD_MOVER_EMPTY_RESET_TIMEOUT => :int,
      :AW_WORLD_MOVER_USED_RESET_TIMEOUT => :int,
      :AW_WORLD_NAME => :string,
      :AW_WORLD_OBJECT_COUNT => :int,
      :AW_WORLD_OBJECT_PASSWORD => :data,
      :AW_WORLD_OBJECT_PATH => :string,
      :AW_WORLD_OBJECT_REFRESH => :int,
      :AW_WORLD_PUBLIC_SPEAKER_CAPABILITY => :bool,
      :AW_WORLD_PUBLIC_SPEAKER_RIGHT => :string,
      :AW_WORLD_RATING => :int,
      :AW_WORLD_REPEATING_GROUND => :bool,
      :AW_WORLD_RESTRICTED_RADIUS => :int,
      :AW_WORLD_SIZE => :int,
      :AW_WORLD_SKY_BOTTOM_BLUE => :int,
      :AW_WORLD_SKY_BOTTOM_GREEN => :int,
      :AW_WORLD_SKY_BOTTOM_RED => :int,
      :AW_WORLD_SKY_EAST_BLUE => :int,
      :AW_WORLD_SKY_EAST_GREEN => :int,
      :AW_WORLD_SKY_EAST_RED => :int,
      :AW_WORLD_SKY_NORTH_BLUE => :int,
      :AW_WORLD_SKY_NORTH_GREEN => :int,
      :AW_WORLD_SKY_NORTH_RED => :int,
      :AW_WORLD_SKY_SOUTH_BLUE => :int,
      :AW_WORLD_SKY_SOUTH_GREEN => :int,
      :AW_WORLD_SKY_SOUTH_RED => :int,
      :AW_WORLD_SKY_TOP_BLUE => :int,
      :AW_WORLD_SKY_TOP_GREEN => :int,
      :AW_WORLD_SKY_TOP_RED => :int,
      :AW_WORLD_SKY_WEST_BLUE => :int,
      :AW_WORLD_SKY_WEST_GREEN => :int,
      :AW_WORLD_SKY_WEST_RED => :int,
      :AW_WORLD_SKYBOX => :string,
      :AW_WORLD_SLOPESLIDE_ENABLED => :bool,
      :AW_WORLD_SLOPESLIDE_MAX_ANGLE => :float,
      :AW_WORLD_SLOPESLIDE_MIN_ANGLE => :float,
      :AW_WORLD_SOUND_AMBIENT => :string,
      :AW_WORLD_SOUND_FOOTSTEP => :string,
      :AW_WORLD_SOUND_WATER_ENTER => :string,
      :AW_WORLD_SOUND_WATER_EXIT => :string,
      :AW_WORLD_SPEAK_CAPABILITY => :bool,
      :AW_WORLD_SPEAK_RIGHT => :string,
      :AW_WORLD_SPECIAL_COMMANDS => :string,
      :AW_WORLD_SPECIAL_COMMANDS_RIGHT => :string,
      :AW_WORLD_SPECIAL_OBJECTS_RIGHT => :string,
      :AW_WORLD_TERRAIN_AMBIENT => :float,
      :AW_WORLD_TERRAIN_DIFFUSE => :float,
      :AW_WORLD_TERRAIN_OFFSET => :float,
      :AW_WORLD_TERRAIN_RIGHT => :string,
      :AW_WORLD_TERRAIN_TIMESTAMP => :int,
      :AW_WORLD_TITLE => :string,
      :AW_WORLD_V4_OBJECTS_RIGHT => :string,
      :AW_WORLD_WAIT_LIMIT => :int,
      :AW_WORLD_WATER_BLUE => :int,
      :AW_WORLD_WATER_BOTTOM_MASK => :string,
      :AW_WORLD_WATER_BOTTOM_TEXTURE => :string,
      :AW_WORLD_WATER_ENABLED => :bool,
      :AW_WORLD_WATER_FRICTION => :float,
      :AW_WORLD_WATER_GREEN => :int,
      :AW_WORLD_WATER_LEVEL => :float,
      :AW_WORLD_WATER_MASK => :string,
      :AW_WORLD_WATER_OPACITY => :int,
      :AW_WORLD_WATER_RED => :int,
      :AW_WORLD_WATER_SPEED => :float,
      :AW_WORLD_WATER_SURFACE_MOVE => :float,
      :AW_WORLD_WATER_TEXTURE => :string,
      :AW_WORLD_WATER_UNDER_TERRAIN => :bool,
      :AW_WORLD_WATER_WAVE_MOVE => :float,
      :AW_WORLD_WATER_VISIBILITY => :int,
      :AW_WORLD_WELCOME_MESSAGE => :string,
      :AW_WORLD_VOIP_CONFERENCE_GLOBAL => :bool,
      :AW_WORLD_VOIP_MODERATE_GLOBAL => :bool,
      :AW_WORLD_VOIP_RIGHT => :string 
    }

    RETURN_CODE_MAP = {
      0 => {:error_symbol => :RC_SUCCESS, :error_explanation => "Success: Return value from an asynchronous call:	 	Request has been sent to the server.\nReturn value from a blocking call:	 	Operation has completed successfully.\nWhen passed to a callback:	 	Operation has completed successfully."},
      1 => {:error_symbol => :RC_CITIZENSHIP_EXPIRED, :error_explanation => "Citizenship has expired: Citizenship of the owner has expired."},
      2 => {:error_symbol => :RC_LAND_LIMIT_EXCEEDED, :error_explanation => "Land limit exceeded: Land limit of the universe would be exceeded if the world is started."},
      3 => {:error_symbol => :RC_NO_SUCH_CITIZEN, :error_explanation => "No such citizen: No citizenship with a matching citizen number was found."},
      5 => {:error_symbol => :RC_LICENSE_PASSWORD_CONTAINS_SPACE, :error_explanation => "License password contains space: Password cannot contain a space."},
      6 => {:error_symbol => :RC_LICENSE_PASSWORD_TOO_LONG, :error_explanation => "License password too long:  Password cannot be longer than 8 characters."},
      7 => {:error_symbol => :RC_LICENSE_PASSWORD_TOO_SHORT, :error_explanation => "License password too short: Password must be at least 2 characters."},
      8 => {:error_symbol => :RC_LICENSE_RANGE_TOO_LARGE, :error_explanation => "License range too large: Range must be smaller than 3275 hectometers. That is, at most 32750 coordinates N/S/W/E or 655000 meters across."},
      9 => {:error_symbol => :RC_LICENSE_RANGE_TOO_SMALL, :error_explanation => "License range too small: Range must be larger than 0 hectometers. That is, at least 10 coordinates N/S/W/E or 200 meters across."},
      10 => {:error_symbol => :RC_LICENSE_USERS_TOO_LARGE, :error_explanation => "License users too large: User limit cannot exceed 1024."},
      11 => {:error_symbol => :RC_LICENSE_USERS_TOO_SMALL, :error_explanation => "License users too small: User limit must be larger than 0."},
      13 => {:error_symbol => :RC_INVALID_PASSWORD, :error_explanation => "Invalid password: Unable to login due to invalid password."},
      15 => {:error_symbol => :RC_LICENSE_WORLD_TOO_SHORT, :error_explanation => "License world too short: Name must be at least 2 characters."},
      16 => {:error_symbol => :RC_LICENSE_WORLD_TOO_LONG, :error_explanation => "License world too long: Name cannot be longer than 8 characters."},
      20 => {:error_symbol => :RC_INVALID_WORLD, :error_explanation => "Invalid world: Unable to start the world due to invalid name or password."},
      21 => {:error_symbol => :RC_SERVER_OUTDATED, :error_explanation => "Server outdated: Server build either contains a serious flaw or is outdated and must be upgraded."},
      22 => {:error_symbol => :RC_WORLD_ALREADY_STARTED, :error_explanation => "World already started: World has already been started at a different location."},
      27 => {:error_symbol => :RC_NO_SUCH_WORLD, :error_explanation => "No such world: No world with a matching name has been started on the server."},
      32 => {:error_symbol => :RC_UNAUTHORIZED, :error_explanation => "Unauthorized: Not authorized to perform the operation."},
      33 => {:error_symbol => :RC_WORLD_ALREADY_EXISTS, :error_explanation => "World already exists: TODO: Might not be in use."},
      34 => {:error_symbol => :RC_NO_SUCH_LICENSE, :error_explanation => "No such license: No license with a matching world name was found."},
      57 => {:error_symbol => :RC_TOO_MANY_WORLDS, :error_explanation => "Too many worlds: Limit of started worlds in the universe would be exceeded if the world is started."},
      58 => {:error_symbol => :RC_MUST_UPGRADE, :error_explanation => "Must upgrade: SDK build either contains a serious flaw or is outdated and must be upgraded."},
      59 => {:error_symbol => :RC_BOT_LIMIT_EXCEEDED, :error_explanation => "Bot limit exceeded: Bot limit of the owner citizenship would be exceeded if the bot is logged in."},
      61 => {:error_symbol => :RC_WORLD_EXPIRED, :error_explanation => "World expired: Unable to start world due to its license having expired."},
      62 => {:error_symbol => :RC_CITIZEN_DOES_NOT_EXPIRE, :error_explanation => "Citizen does not expire: TODO: What is this used for?"},
      64 => {:error_symbol => :RC_LICENSE_STARTS_WITH_NUMBER, :error_explanation => "License starts with number: Name cannot start with a number."},
      66 => {:error_symbol => :RC_NO_SUCH_EJECTION, :error_explanation => "No such ejection: No ejection with a matching identifier was found."},
      67 => {:error_symbol => :RC_NO_SUCH_SESSION, :error_explanation => "No such session: No user with a matching session number has entered the world."},
      72 => {:error_symbol => :RC_WORLD_RUNNING, :error_explanation => "World running: World has already been started."},
      73 => {:error_symbol => :RC_WORLD_NOT_SET, :error_explanation => "World not set: World to perform the operation on has not been set."},
      74 => {:error_symbol => :RC_NO_SUCH_CELL, :error_explanation => "No such cell: No more cells left to enumerate."},
      75 => {:error_symbol => :RC_NO_REGISTRY, :error_explanation => "No registry: Unable to start world due to missing or invalid registry."},
      76 => {:error_symbol => :RC_CANT_OPEN_REGISTRY, :error_explanation => "Can't open registry"},
      77 => {:error_symbol => :RC_CITIZEN_DISABLED, :error_explanation => "Citizen disabled: Citizenship of the owner has been disabled."},
      78 => {:error_symbol => :RC_WORLD_DISABLED, :error_explanation => "World disabled: Unable to start world due to it having been disabled."},
      85 => {:error_symbol => :RC_TELEGRAM_BLOCKED, :error_explanation => "Telegram blocked"},
      88 => {:error_symbol => :RC_UNABLE_TO_UPDATE_TERRAIN, :error_explanation => "Unable to update terrain"},
      100 => {:error_symbol => :RC_EMAIL_CONTAINS_INVALID_CHAR, :error_explanation => "Email contains invalid char: Email address contains one or more invalid characters."},
      101 => {:error_symbol => :RC_EMAIL_ENDS_WITH_BLANK, :error_explanation => "Email ends with blank: Email address cannot end with a blank."},
      101 => {:error_symbol => :RC_NO_SUCH_OBJECT, :error_explanation => "No such object: Unable to find the object to delete."},
      102 => {:error_symbol => :RC_EMAIL_MISSING_DOT, :error_explanation => "Email missing dot: Email address must contain at least one '.'."},
      102 => {:error_symbol => :RC_NOT_DELETE_OWNER, :error_explanation => "Not delete owner"},
      103 => {:error_symbol => :RC_EMAIL_MISSING_AT, :error_explanation => "Email missing at: Email address must contain a '@'."},
      104 => {:error_symbol => :RC_EMAIL_STARTS_WITH_BLANK, :error_explanation => "Email starts with blank: Email address cannot start with a blank."},
      105 => {:error_symbol => :RC_EMAIL_TOO_LONG, :error_explanation => "Email too long: Email address cannot be longer than 50 characters."},
      106 => {:error_symbol => :RC_EMAIL_TOO_SHORT, :error_explanation => "Email too short: Email address must be at least 8 characters or longer."},
      107 => {:error_symbol => :RC_NAME_ALREADY_USED, :error_explanation => "Name already used: Citizenship with a matching name already exists."},
      108 => {:error_symbol => :RC_NAME_CONTAINS_NONALPHANUMERIC_CHAR, :error_explanation => "Name contains nonalphanumeric character: Name contains invalid character(s)."},
      109 => {:error_symbol => :RC_NAME_CONTAINS_INVALID_BLANK, :error_explanation => "Name contains invalid blank: Name contains invalid blank(s)."},
      111 => {:error_symbol => :RC_NAME_ENDS_WITH_BLANK, :error_explanation => "Name ends with blank: Name cannot end with a blank."},
      112 => {:error_symbol => :RC_NAME_TOO_LONG, :error_explanation => "Name too long: Name cannot be longer than 16 characters."},
      113 => {:error_symbol => :RC_NAME_TOO_SHORT, :error_explanation => "Name too short: Name must be at least 2 characters."},
      115 => {:error_symbol => :RC_PASSWORD_TOO_LONG, :error_explanation => "Password too long: Password cannot be longer than 12 characters."},
      116 => {:error_symbol => :RC_PASSWORD_TOO_SHORT, :error_explanation => "Password too short: Password must be at least 4 characters."},
      124 => {:error_symbol => :RC_UNABLE_TO_DELETE_CITIZEN, :error_explanation => "Unable to delete citizen: Unable to delete citizen due to a database problem."},
      126 => {:error_symbol => :RC_NUMBER_ALREADY_USED, :error_explanation => "Number already used: Citizenship with a matching citizen number already exists."},
      127 => {:error_symbol => :RC_NUMBER_OUT_OF_RANGE, :error_explanation => "Number out of range: Citizen number is larger than the auto-incremented field in the database."},
      128 => {:error_symbol => :RC_PRIVILEGE_PASSWORD_IS_TOO_SHORT, :error_explanation => "Privilege password is too short: Privilege password must be either empty or at least 4 characters."},
      129 => {:error_symbol => :RC_PRIVILEGE_PASSWORD_IS_TOO_LONG, :error_explanation => "Privilege password is too long: Password cannot be longer than 12 characters."},
      203 => {:error_symbol => :RC_NOT_CHANGE_OWNER, :error_explanation => "Not change owner: Not permitted to change the owner of an object. It requires eminent domain or caretaker capability."},
      204 => {:error_symbol => :RC_CANT_FIND_OLD_ELEMENT, :error_explanation => "Can't find old element: Unable to find the object to change."},
      212 => {:error_symbol => :RC_IMPOSTER, :error_explanation => "Imposter: Unable to enter world due to masquerading as someone else."},
      300 => {:error_symbol => :RC_ENCROACHES, :error_explanation => "Encroaches: Not allowed to encroach into another's property."},
      301 => {:error_symbol => :RC_OBJECT_TYPE_INVALID, :error_explanation => "Object type invalid"},
      303 => {:error_symbol => :RC_TOO_MANY_BYTES, :error_explanation => "Too many bytes: Cell limit would be exceeded."},
      306 => {:error_symbol => :RC_UNREGISTERED_OBJECT, :error_explanation => "Unregistered object: Model name does not exist in the registry."},
      308 => {:error_symbol => :RC_ELEMENT_ALREADY_EXISTS, :error_explanation => "Element already exists"},
      309 => {:error_symbol => :RC_RESTRICTED_COMMAND, :error_explanation => "Restricted command"},
      311 => {:error_symbol => :RC_OUT_OF_BOUNDS, :error_explanation => "Out of bounds"},
      313 => {:error_symbol => :RC_RESTRICTED_OBJECT, :error_explanation => "Restricted object: Not allowed to build with 'z' objects in this world."},
      314 => {:error_symbol => :RC_RESTRICTED_AREA, :error_explanation => "Restricted area: Not allowed to build within the restricted area of this world."},
      401 => {:error_symbol => :RC_NOT_YET, :error_explanation => "Not yet: Would exceed the maximum number of operations per second."},
      402 => {:error_symbol => :RC_TIMEOUT, :error_explanation => "Timeout: Synchronous operation timed out."},
      404 => {:error_symbol => :RC_UNABLE_TO_CONTACT_UNIVERSE, :error_explanation => "Unable to contact universe: Unable to establish a connection to the universe server."},
      439 => {:error_symbol => :RC_NO_CONNECTION, :error_explanation => "No connection: Connection to the server is down."},
      444 => {:error_symbol => :RC_NOT_INITIALIZED, :error_explanation => "Not initialized: SDK API has not been initialized (by calling aw_init)."},
      445 => {:error_symbol => :RC_NO_INSTANCE, :error_explanation => "No instance"},
      448 => {:error_symbol => :RC_INVALID_ATTRIBUTE, :error_explanation => "Invalid attribute"},
      449 => {:error_symbol => :RC_TYPE_MISMATCH, :error_explanation => "Type mismatch"},
      450 => {:error_symbol => :RC_STRING_TOO_LONG, :error_explanation => "String too long"},
      451 => {:error_symbol => :RC_READ_ONLY, :error_explanation => "Read only: Unable to set attribute due to it being read-only."},
      453 => {:error_symbol => :RC_INVALID_INSTANCE, :error_explanation => "Invalid instance"},
      454 => {:error_symbol => :RC_VERSION_MISMATCH, :error_explanation => "Version mismatch: Aw.h and Aw.dll (or libaw_sdk.so for Linux) are from different builds of the SDK."},
      464 => {:error_symbol => :RC_QUERY_IN_PROGRESS, :error_explanation => "Query in progress: A property query is already in progress."},
      466 => {:error_symbol => :RC_EJECTED, :error_explanation => "Ejected: Disconnected from world due to ejection."},
      467 => {:error_symbol => :RC_NOT_WELCOME, :error_explanation => "Not welcome: Citizenship of the owner does not have bot rights in the world."},
      471 => {:error_symbol => :RC_CONNECTION_LOST, :error_explanation => "Connection lost"},
      474 => {:error_symbol => :RC_NOT_AVAILABLE, :error_explanation => "Not available"},
      500 => {:error_symbol => :RC_CANT_RESOLVE_UNIVERSE_HOST, :error_explanation => "Can't resolve universe host"},
      505 => {:error_symbol => :RC_INVALID_ARGUMENT, :error_explanation => "Invalid argument"},
      514 => {:error_symbol => :RC_UNABLE_TO_UPDATE_CAV, :error_explanation => "Unable to update custom avatar"},
      515 => {:error_symbol => :RC_UNABLE_TO_DELETE_CAV, :error_explanation => "Unable to delete custom avatar"},
      516 => {:error_symbol => :RC_NO_SUCH_CAV, :error_explanation => "No such custom avatar"},
      521 => {:error_symbol => :RC_WORLD_INSTANCE_ALREADY_EXISTS, :error_explanation => "World instance already exists"},
      522 => {:error_symbol => :RC_WORLD_INSTANCE_INVALID, :error_explanation => "World instance invalid"},
      523 => {:error_symbol => :RC_PLUGIN_NOT_AVAILABLE, :error_explanation => "Plugin not available"},
      600 => {:error_symbol => :RC_DATABASE_ERROR, :error_explanation => "Database error"},
      4995 => {:error_symbol => :RC_Z_BUF_ERROR, :error_explanation => "Buffer error (zlib)	Not enough room in the output buffer."},
      4996 => {:error_symbol => :RC_Z_MEM_ERROR, :error_explanation => "Memory error (zlib): Memory could not be allocated for processing."},
      4997 => {:error_symbol => :RC_Z_DATA_ERROR, :error_explanation => "Data error (zlib): Input data was corrupted."}
    }

    RETURN_CODE_SYMBOL_MAP = begin
      h = {}
      RETURN_CODE_MAP.each_pair do |rc_int,hsh|
        h.merge!({hsh[:error_symbol] => {:rc => rc_int, :error_explanation => hsh[:error_explanation]}})
      end
      h
    end
  
    def self.set_attributes_for(callback_or_event, *attributes)
      @@attrs_available_to ||= {}
      @@attrs_available_to[callback_or_event] = attributes
    end

    class << self
      alias :callback_attributes_for :set_attributes_for
      alias :event_attributes_for :set_attributes_for
    end
  
    callback_attributes_for :AW_CALLBACK_ADDRESS, :AW_AVATAR_SESSION, :AW_AVATAR_ADDRESS
    callback_attributes_for :AW_CALLBACK_AVATAR_LOCATION, :AW_AVATAR_SESSION,
      :AW_AVATAR_NAME, :AW_AVATAR_X, :AW_AVATAR_Y, :AW_AVATAR_Z, :AW_AVATAR_YAW, :AW_AVATAR_PITCH,
      :AW_AVATAR_TYPE, :AW_AVATAR_GESTURE, :AW_AVATAR_STATE, :AW_AVATAR_VERSION,
      :AW_AVATAR_CITIZEN, :AW_AVATAR_PRIVILEGE, :AW_AVATAR_LOCK, :AW_PLUGIN_STRING
    callback_attributes_for :AW_CALLBACK_ADMIN_WORLD_RESULT,
      :AW_SERVER_ID, :AW_SERVER_INSTANCE, :AW_SERVER_NAME

    callback_attributes_for :AW_CALLBACK_ADMIN_WORLD_LIST, :AW_SERVER_ID
    callback_attributes_for :AW_CALLBACK_ADMIN, :AW_SERVER_BUILD, :AW_WORLD_BUILD_NUMBER

    callback_attributes_for :AW_CALLBACK_CELL_RESULT, :AW_CELL_ITERATOR
    callback_attributes_for :AW_CALLBACK_CITIZEN_RESULT, :AW_CITIZEN_NUMBER
    callback_attributes_for :AW_CALLBACK_CITIZEN_ATTRIBUTES,
      :AW_CITIZEN_NUMBER, :AW_CITIZEN_NAME, :AW_CITIZEN_PASSWORD,
      :AW_CITIZEN_EMAIL, :AW_CITIZEN_ENABLED, :AW_CITIZEN_BETA,
      :AW_CITIZEN_TRIAL, 
      :AW_CITIZEN_CAV_ENABLED, :AW_CITIZEN_PAV_ENABLED,
      :AW_CITIZEN_BOT_LIMIT, :AW_CITIZEN_COMMENT, :AW_CITIZEN_EXPIRATION_TIME,
      :AW_CITIZEN_IMMIGRATION_TIME, :AW_CITIZEN_LAST_LOGIN,
      :AW_CITIZEN_PRIVILEGE_PASSWORD, :AW_CITIZEN_PRIVACY,
      :AW_CITIZEN_TOTAL_TIME, :AW_CITIZEN_URL

    callback_attributes_for :AW_CALLBACK_ENTER, :AW_WORLD_NAME

    callback_attributes_for :AW_CALLBACK_HUD_RESULT, :AW_HUD_ELEMENT_SESSION, :AW_HUD_ELEMENT_ID

    callback_attributes_for :AW_CALLBACK_LICENSE_ATTRIBUTES,
      :AW_LICENSE_PASSWORD, :AW_LICENSE_USERS, :AW_LICENSE_RANGE,
      :AW_LICENSE_EMAIL, :AW_LICENSE_COMMENT, :AW_LICENSE_CREATION_TIME,
      :AW_LICENSE_EXPIRATION_TIME, :AW_LICENSE_LAST_START,
      :AW_LICENSE_LAST_ADDRESS, :AW_LICENSE_HIDDEN, :AW_LICENSE_ALLOW_TOURISTS,
      :AW_LICENSE_VOIP, :AW_LICENSE_PLUGINS

    callback_attributes_for :AW_CALLBACK_LOGIN, :AW_CITIZEN_BETA,
      :AW_CITIZEN_CAV_ENABLED, 
      :AW_CITIZEN_NAME, :AW_CITIZEN_NUMBER,
      :AW_CITIZEN_PAV_ENABLED, 
      :AW_CITIZEN_TIME_LEFT, :AW_LOGIN_PRIVILEGE_NAME

    callback_attributes_for :AW_CALLBACK_OBJECT_RESULT, :AW_OBJECT_NUMBER,
      :AW_OBJECT_ID, :AW_OBJECT_CALLBACK_REFERENCE, :AW_CELL_X, :AW_CELL_Z
    callback_attributes_for :AW_CALLBACK_OBJECT_QUERY, 
      :AW_OBJECT_TYPE, :AW_OBJECT_ID, :AW_OBJECT_NUMBER, :AW_OBJECT_OWNER,
      :AW_OBJECT_BUILD_TIMESTAMP, :AW_OBJECT_X, :AW_OBJECT_Y, :AW_OBJECT_Z,
      :AW_OBJECT_YAW, :AW_OBJECT_TILT, :AW_OBJECT_ROLL, :AW_OBJECT_MODEL,
      :AW_OBJECT_DESCRIPTION, :AW_OBJECT_ACTION, :AW_OBJECT_DATA

    callback_attributes_for :AW_CALLBACK_QUERY, :AW_QUERY_COMPLETE
    callback_attributes_for :AW_CALLBACK_TERRAIN_NEXT_RESULT, :AW_TERRAIN_COMPLETE
    callback_attributes_for :AW_CALLBACK_TERRAIN_SET_RESULT, :AW_TERRAIN_X, :AW_TERRAIN_Z

    callback_attributes_for :AW_CALLBACK_USER_LIST, :AW_USERLIST_MORE
    callback_attributes_for :AW_CALLBACK_UNIVERSE_EJECTION, :AW_EJECTION_ADDRESS,
      :AW_EJECTION_CREATION_TIME, :AW_EJECTION_EXPIRATION_TIME, :AW_EJECTION_COMMENT

    callback_attributes_for :AW_CALLBACK_WORLD_LIST, :AW_WORLDLIST_MORE
    callback_attributes_for :AW_CALLBACK_WORLD_EJECTION, :AW_EJECTION_TYPE,
      :AW_EJECTION_ADDRESS, :AW_EJECTION_CREATION_TIME, :AW_EJECTION_EXPIRATION_TIME, 
      :AW_EJECTION_COMMENT
    callback_attributes_for :AW_CALLBACK_WORLD_INSTANCE, :AW_AVATAR_CITIZEN, :AW_AVATAR_WORLD_INSTANCE
  
    event_attributes_for :AW_EVENT_AVATAR_ADD, :AW_AVATAR_SESSION, :AW_AVATAR_NAME,
      :AW_AVATAR_X, :AW_AVATAR_Y, :AW_AVATAR_Z, :AW_AVATAR_YAW, :AW_AVATAR_TYPE, 
      :AW_AVATAR_GESTURE, :AW_AVATAR_VERSION, :AW_AVATAR_CITIZEN, :AW_AVATAR_PRIVILEGE, 
      :AW_AVATAR_PITCH, :AW_AVATAR_STATE, :AW_PLUGIN_STRING
    event_attributes_for :AW_EVENT_AVATAR_CHANGE, :AW_AVATAR_SESSION, :AW_AVATAR_NAME,
      :AW_AVATAR_X, :AW_AVATAR_Y, :AW_AVATAR_Z, :AW_AVATAR_YAW, :AW_AVATAR_TYPE, 
      :AW_AVATAR_GESTURE, :AW_AVATAR_PITCH, :AW_AVATAR_STATE, :AW_AVATAR_FLAGS, 
      :AW_AVATAR_LOCK, :AW_PLUGIN_STRING
    event_attributes_for :AW_EVENT_AVATAR_CLICK, :AW_AVATAR_NAME, 
      :AW_AVATAR_SESSION, :AW_CLICKED_NAME, :AW_CLICKED_SESSION
    event_attributes_for :AW_EVENT_AVATAR_DELETE, :AW_AVATAR_SESSION, :AW_AVATAR_NAME
    event_attributes_for :AW_EVENT_AVATAR_RELOAD, :AW_AVATAR_CITIZEN, :AW_AVATAR_SESSION

    event_attributes_for :AW_EVENT_BOTMENU, :AW_BOTMENU_FROM_NAME, 
      :AW_BOTMENU_FROM_SESSION, :AW_BOTMENU_QUESTION, :AW_BOTMENU_ANSWER
    event_attributes_for :AW_EVENT_BOTGRAM, :AW_BOTGRAM_FROM_NAME, 
      :AW_BOTGRAM_FROM, :AW_BOTGRAM_TEXT

    event_attributes_for :AW_EVENT_CHAT, :AW_AVATAR_NAME, :AW_CHAT_SESSION, 
      :AW_CHAT_TYPE, :AW_CHAT_MESSAGE
    event_attributes_for :AW_EVENT_CELL_BEGIN, :AW_CELL_X, :AW_CELL_Z, 
      :AW_CELL_SEQUENCE, :AW_CELL_SIZE
    event_attributes_for :AW_EVENT_CELL_END, []
    event_attributes_for :AW_EVENT_CELL_OBJECT, :AW_OBJECT_TYPE, 
      :AW_OBJECT_ID, :AW_OBJECT_NUMBER, :AW_OBJECT_OWNER, 
      :AW_OBJECT_BUILD_TIMESTAMP, :AW_OBJECT_X, :AW_OBJECT_Y, :AW_OBJECT_Z, 
      :AW_OBJECT_YAW, :AW_OBJECT_TILT, :AW_OBJECT_ROLL, :AW_OBJECT_MODEL, 
      :AW_OBJECT_DESCRIPTION, :AW_OBJECT_ACTION, :AW_OBJECT_DATA
    event_attributes_for :AW_EVENT_CONSOLE_MESSAGE, :AW_CONSOLE_RED, 
      :AW_CONSOLE_GREEN, :AW_CONSOLE_BLUE, :AW_CONSOLE_MESSAGE, :AW_CONSOLE_BOLD, 
      :AW_CONSOLE_ITALICS

    event_attributes_for :AW_EVENT_ENTITY_ADD, :AW_ENTITY_TYPE, :AW_ENTITY_ID,
      :AW_ENTITY_STATE, :AW_ENTITY_FLAGS, :AW_ENTITY_NUMBER, 
      :AW_ENTITY_OWNER_SESSION, :AW_ENTITY_X, :AW_ENTITY_Y, :AW_ENTITY_Z, 
      :AW_ENTITY_YAW, :AW_ENTITY_TILT, :AW_ENTITY_ROLL, :AW_ENTITY_MODE_NUM,
      :AW_ENTITY_OWNER_CITIZEN,
      :AW_OBJECT_SESSION, :AW_CELL_SEQUENCE, 
      :AW_CELL_X, :AW_CELL_Z, :AW_OBJECT_TYPE, :AW_OBJECT_ID, :AW_OBJECT_NUMBER, 
      :AW_OBJECT_OWNER, :AW_OBJECT_BUILD_TIMESTAMP, :AW_OBJECT_X, :AW_OBJECT_Y, 
      :AW_OBJECT_Z, :AW_OBJECT_YAW, :AW_OBJECT_TILT, :AW_OBJECT_ROLL, :AW_OBJECT_MODEL, 
      :AW_OBJECT_DESCRIPTION, :AW_OBJECT_ACTION, :AW_OBJECT_DATA
    event_attributes_for :AW_EVENT_ENTITY_CHANGE, :AW_ENTITY_TYPE, :AW_ENTITY_ID,
      :AW_ENTITY_STATE, :AW_ENTITY_FLAGS,
      :AW_ENTITY_OWNER_SESSION, :AW_ENTITY_X, :AW_ENTITY_Y, :AW_ENTITY_Z, 
      :AW_ENTITY_YAW, :AW_ENTITY_TILT, :AW_ENTITY_ROLL, :AW_ENTITY_MODE_NUM
    event_attributes_for :AW_EVENT_ENTITY_DELETE, :AW_ENTITY_TYPE, :AW_ENTITY_ID
    event_attributes_for :AW_EVENT_ENTITY_LINKS, :AW_ENTITY_TYPE, :AW_ENTITY_ID,
      :AW_OBJECT_SESSION, :AW_CELL_SEQUENCE, 
      :AW_CELL_X, :AW_CELL_Z, :AW_OBJECT_TYPE, :AW_OBJECT_ID, :AW_OBJECT_NUMBER, 
      :AW_OBJECT_OWNER, :AW_OBJECT_BUILD_TIMESTAMP, :AW_OBJECT_X, :AW_OBJECT_Y, 
      :AW_OBJECT_Z, :AW_OBJECT_YAW, :AW_OBJECT_TILT, :AW_OBJECT_ROLL, :AW_OBJECT_MODEL, 
      :AW_OBJECT_DESCRIPTION, :AW_OBJECT_ACTION, :AW_OBJECT_DATA

    event_attributes_for :AW_EVENT_ENTITY_RIDER_ADD, :AW_ENTITY_TYPE, :AW_ENTITY_ID,
      :AW_AVATAR_SESSION, :AW_AVATAR_DISTANCE, :AW_AVATAR_Y_DELTA, :AW_AVATAR_ANGLE, 
      :AW_AVATAR_YAW_DELTA, :AW_AVATAR_PITCH_DELTA
    event_attributes_for :AW_EVENT_ENTITY_RIDER_CHANGE, :AW_ENTITY_TYPE, :AW_ENTITY_ID,
      :AW_AVATAR_SESSION, :AW_AVATAR_DISTANCE, :AW_AVATAR_Y_DELTA, :AW_AVATAR_ANGLE, 
      :AW_AVATAR_YAW_DELTA, :AW_AVATAR_PITCH_DELTA
    event_attributes_for :AW_EVENT_ENTITY_RIDER_DELETE, :AW_ENTITY_TYPE, :AW_OBJECT_ID, :AW_AVATAR_SESSION

    event_attributes_for :AW_EVENT_HUD_CLICK, :AW_HUD_ELEMENT_SESSION, 
      :AW_HUD_ELEMENT_ID, :AW_HUD_ELEMENT_CLICK_X, :AW_HUD_ELEMENT_CLICK_Y

    event_attributes_for :AW_EVENT_NOISE, :AW_SOUND_NAME

    event_attributes_for :AW_EVENT_OBJECT_ADD, :AW_OBJECT_SESSION, :AW_CELL_SEQUENCE, 
        :AW_CELL_X, :AW_CELL_Z, :AW_OBJECT_TYPE, :AW_OBJECT_ID, :AW_OBJECT_NUMBER, 
        :AW_OBJECT_OWNER, :AW_OBJECT_BUILD_TIMESTAMP, :AW_OBJECT_X, :AW_OBJECT_Y, 
        :AW_OBJECT_Z, :AW_OBJECT_YAW, :AW_OBJECT_TILT, :AW_OBJECT_ROLL, :AW_OBJECT_MODEL, 
        :AW_OBJECT_DESCRIPTION, :AW_OBJECT_ACTION, :AW_OBJECT_DATA
    event_attributes_for :AW_EVENT_OBJECT_BUMP, :AW_AVATAR_SESSION, :AW_AVATAR_NAME,
      :AW_OBJECT_SYNC, :AW_OBJECT_TYPE, :AW_OBJECT_ID, 
      :AW_OBJECT_X, :AW_OBJECT_Y, :AW_OBJECT_Z,
      :AW_OBJECT_YAW, :AW_OBJECT_TILT, :AW_OBJECT_ROLL, :AW_OBJECT_MODEL, 
      :AW_OBJECT_OWNER, :AW_OBJECT_BUILD_TIMESTAMP,  
      :AW_OBJECT_DESCRIPTION, :AW_OBJECT_ACTION, :AW_OBJECT_DATA

    event_attributes_for :AW_EVENT_OBJECT_CLICK, :AW_AVATAR_SESSION, :AW_AVATAR_NAME,
      :AW_OBJECT_SYNC, :AW_CELL_X, :AW_CELL_Z,
      :AW_OBJECT_TYPE, :AW_OBJECT_ID, :AW_OBJECT_NUMBER, 
      :AW_OBJECT_OWNER, :AW_OBJECT_BUILD_TIMESTAMP, :AW_OBJECT_X, :AW_OBJECT_Y, 
      :AW_OBJECT_Z, :AW_OBJECT_YAW, :AW_OBJECT_TILT, :AW_OBJECT_ROLL, :AW_OBJECT_MODEL, 
      :AW_OBJECT_DESCRIPTION, :AW_OBJECT_ACTION, :AW_OBJECT_DATA

    event_attributes_for :AW_EVENT_OBJECT_DELETE, :AW_OBJECT_SESSION, :AW_CELL_SEQUENCE, 
        :AW_CELL_X, :AW_CELL_Z, :AW_OBJECT_ID, :AW_OBJECT_NUMBER
    event_attributes_for :AW_EVENT_OBJECT_SELECT, :AW_AVATAR_SESSION, :AW_AVATAR_NAME,
      :AW_OBJECT_SYNC, :AW_CELL_X, :AW_CELL_Z, :AW_OBJECT_ID, :AW_OBJECT_NUMBER

    event_attributes_for :AW_EVENT_TELEPORT, :AW_TELEPORT_WORLD,
      :AW_TELEPORT_X, :AW_TELEPORT_Y, :AW_TELEPORT_Z, :AW_TELEPORT_YAW, :AW_TELEPORT_WARP

    event_attributes_for :AW_EVENT_TERRAIN_BEGIN, :AW_TERRAIN_PAGE_X, :AW_TERRAIN_PAGE_Z
    event_attributes_for :AW_EVENT_TERRAIN_CHANGE, :AW_TERRAIN_PAGE_X, :AW_TERRAIN_PAGE_Z
    event_attributes_for :AW_EVENT_TERRAIN_DATA, :AW_TERRAIN_NODE_X, 
      :AW_TERRAIN_NODE_Z, :AW_TERRAIN_NODE_SIZE, :AW_TERRAIN_NODE_TEXTURES, :AW_TERRAIN_NODE_HEIGHTS
    event_attributes_for :AW_EVENT_TERRAIN_END, :AW_TERRAIN_COMPLETE, :AW_TERRAIN_SEQUENCE
    event_attributes_for :AW_EVENT_TOOLBAR_CLICK, :AW_TOOLBAR_SESSION, :AW_TOOLBAR_ID

    event_attributes_for :AW_EVENT_URL, :AW_AVATAR_SESSION, :AW_AVATAR_NAME, 
      :AW_URL_NAME, :AW_URL_POST, :AW_URL_TARGET, :AW_URL_TARGET_3D
    event_attributes_for :AW_EVENT_URL_CLICK, :AW_AVATAR_SESSION, :AW_AVATAR_NAME, 
      :AW_URL_NAME
    event_attributes_for :AW_EVENT_USER_INFO, :AW_USERLIST_ID, 
      :AW_USERLIST_NAME, :AW_USERLIST_WORLD, :AW_USERLIST_CITIZEN, :AW_USERLIST_STATE

    event_attributes_for :AW_EVENT_UNIVERSE_ATTRIBUTES, :AW_UNIVERSE_ALLOW_TOURISTS,
      :AW_UNIVERSE_ANNUAL_CHARGE, :AW_UNIVERSE_BROWSER_BETA, :AW_UNIVERSE_BROWSER_MINIMUM,
      :AW_UNIVERSE_BROWSER_RELEASE, :AW_UNIVERSE_BUILD_NUMBER, :AW_UNIVERSE_CITIZEN_CHANGES_ALLOWED,
      :AW_UNIVERSE_MONTHLY_CHARGE, :AW_UNIVERSE_REGISTER_METHOD, :AW_UNIVERSE_REGISTRATION_REQUIRED,
      :AW_UNIVERSE_SEARCH_URL, :AW_UNIVERSE_TIME, :AW_UNIVERSE_WELCOME_MESSAGE,
      :AW_UNIVERSE_WORLD_BETA, :AW_UNIVERSE_WORLD_MINIMUM, :AW_UNIVERSE_WORLD_RELEASE,
      :AW_UNIVERSE_WORLD_START, :AW_UNIVERSE_USER_LIST_ENABLED, :AW_UNIVERSE_NOTEPAD_URL,
      :AW_UNIVERSE_CAV_PATH, :AW_UNIVERSE_CAV_PATH2

    event_attributes_for :AW_EVENT_UNIVERSE_DISCONNECT, :AW_DISCONNECT_REASON  

    event_attributes_for :AW_EVENT_WORLD_ATTRIBUTES, :AW_ATTRIB_SENDER_SESSION,
      :AW_WORLD_NAME, :AW_WORLD_TITLE, :AW_WORLD_BACKDROP, :AW_WORLD_GROUND,
      :AW_WORLD_OBJECT_PATH, :AW_WORLD_OBJECT_REFRESH, :AW_WORLD_BUILD_RIGHT,
      :AW_WORLD_EMINENT_DOMAIN_RIGHT, :AW_WORLD_ENTER_RIGHT,
      :AW_WORLD_SPECIAL_OBJECTS_RIGHT, :AW_WORLD_FOG_RED, :AW_WORLD_FOG_GREEN,
      :AW_WORLD_FOG_BLUE, :AW_WORLD_CARETAKER_CAPABILITY,
      :AW_WORLD_RESTRICTED_RADIUS, :AW_WORLD_PUBLIC_SPEAKER_CAPABILITY,
      :AW_WORLD_PUBLIC_SPEAKER_RIGHT, :AW_WORLD_CREATION_TIMESTAMP,
      :AW_WORLD_HOME_PAGE, :AW_WORLD_BUILD_NUMBER, :AW_WORLD_OBJECT_PASSWORD,
      :AW_WORLD_DISABLE_CREATE_URL, :AW_WORLD_RATING, :AW_WORLD_WELCOME_MESSAGE,
      :AW_WORLD_EJECT_RIGHT, :AW_WORLD_EJECT_CAPABILITY, :AW_WORLD_CELL_LIMIT,
      :AW_WORLD_BUILD_CAPABILITY, :AW_WORLD_ALLOW_PASSTHRU, :AW_WORLD_ALLOW_FLYING,
      :AW_WORLD_ALLOW_TELEPORT, :AW_WORLD_ALLOW_OBJECT_SELECT, :AW_WORLD_BOTS_RIGHT,
      :AW_WORLD_SPEAK_CAPABILITY, :AW_WORLD_SPEAK_RIGHT,
      :AW_WORLD_ALLOW_TOURIST_WHISPER, :AW_WORLD_LIGHT_X, :AW_WORLD_LIGHT_Y,
      :AW_WORLD_LIGHT_Z, :AW_WORLD_LIGHT_RED, :AW_WORLD_LIGHT_GREEN,
      :AW_WORLD_LIGHT_BLUE, :AW_WORLD_AMBIENT_LIGHT_RED,
      :AW_WORLD_AMBIENT_LIGHT_GREEN, :AW_WORLD_AMBIENT_LIGHT_BLUE,
      :AW_WORLD_ALLOW_AVATAR_COLLISION, :AW_WORLD_FOG_ENABLE, :AW_WORLD_FOG_MINIMUM,
      :AW_WORLD_FOG_MAXIMUM, :AW_WORLD_FOG_TINTED, :AW_WORLD_MAX_USERS,
      :AW_WORLD_SIZE, :AW_WORLD_OBJECT_COUNT, :AW_WORLD_EXPIRATION,
      :AW_WORLD_SPECIAL_COMMANDS_RIGHT, :AW_WORLD_MAX_LIGHT_RADIUS,
      :AW_WORLD_SKYBOX, :AW_WORLD_MINIMUM_VISIBILITY, :AW_WORLD_REPEATING_GROUND,
      :AW_WORLD_KEYWORDS, :AW_WORLD_ENABLE_TERRAIN, :AW_WORLD_ALLOW_3_AXIS_ROTATION,
      :AW_WORLD_TERRAIN_TIMESTAMP, :AW_WORLD_ENTRY_POINT, :AW_WORLD_SKY_NORTH_RED,
      :AW_WORLD_SKY_NORTH_GREEN, :AW_WORLD_SKY_NORTH_BLUE, :AW_WORLD_SKY_SOUTH_RED,
      :AW_WORLD_SKY_SOUTH_GREEN, :AW_WORLD_SKY_SOUTH_BLUE, :AW_WORLD_SKY_EAST_RED,
      :AW_WORLD_SKY_EAST_GREEN, :AW_WORLD_SKY_EAST_BLUE, :AW_WORLD_SKY_WEST_RED,
      :AW_WORLD_SKY_WEST_GREEN, :AW_WORLD_SKY_WEST_BLUE, :AW_WORLD_SKY_TOP_RED,
      :AW_WORLD_SKY_TOP_GREEN, :AW_WORLD_SKY_TOP_BLUE, :AW_WORLD_SKY_BOTTOM_RED,
      :AW_WORLD_SKY_BOTTOM_GREEN, :AW_WORLD_SKY_BOTTOM_BLUE,
      :AW_WORLD_CLOUDS_LAYER1_TEXTURE, :AW_WORLD_CLOUDS_LAYER1_MASK,
      :AW_WORLD_CLOUDS_LAYER1_TILE, :AW_WORLD_CLOUDS_LAYER1_SPEED_X,
      :AW_WORLD_CLOUDS_LAYER1_SPEED_Z, :AW_WORLD_CLOUDS_LAYER1_OPACITY,
      :AW_WORLD_CLOUDS_LAYER2_TEXTURE, :AW_WORLD_CLOUDS_LAYER2_MASK,
      :AW_WORLD_CLOUDS_LAYER2_TILE, :AW_WORLD_CLOUDS_LAYER2_SPEED_X,
      :AW_WORLD_CLOUDS_LAYER2_SPEED_Z, :AW_WORLD_CLOUDS_LAYER2_OPACITY,
      :AW_WORLD_CLOUDS_LAYER3_TEXTURE, :AW_WORLD_CLOUDS_LAYER3_MASK,
      :AW_WORLD_CLOUDS_LAYER3_TILE, :AW_WORLD_CLOUDS_LAYER3_SPEED_X,
      :AW_WORLD_CLOUDS_LAYER3_SPEED_Z, :AW_WORLD_CLOUDS_LAYER3_OPACITY,
      :AW_WORLD_DISABLE_CHAT, :AW_WORLD_ALLOW_CITIZEN_WHISPER,
      :AW_WORLD_ALWAYS_SHOW_NAMES, :AW_WORLD_DISABLE_AVATAR_LIST,
      :AW_WORLD_AVATAR_REFRESH_RATE, :AW_WORLD_WATER_TEXTURE, :AW_WORLD_WATER_MASK,
      :AW_WORLD_WATER_BOTTOM_TEXTURE, :AW_WORLD_WATER_BOTTOM_MASK,
      :AW_WORLD_WATER_OPACITY, :AW_WORLD_WATER_RED, :AW_WORLD_WATER_GREEN,
      :AW_WORLD_WATER_BLUE, :AW_WORLD_WATER_LEVEL, :AW_WORLD_WATER_SURFACE_MOVE,
      :AW_WORLD_WATER_WAVE_MOVE, :AW_WORLD_WATER_SPEED, :AW_WORLD_WATER_ENABLED,
      :AW_WORLD_EMINENT_DOMAIN_CAPABILITY, :AW_WORLD_LIGHT_TEXTURE,
      :AW_WORLD_LIGHT_MASK, :AW_WORLD_LIGHT_DRAW_SIZE, :AW_WORLD_LIGHT_DRAW_FRONT,
      :AW_WORLD_LIGHT_DRAW_BRIGHT, :AW_WORLD_LIGHT_SOURCE_USE_COLOR,
      :AW_WORLD_LIGHT_SOURCE_COLOR, :AW_WORLD_TERRAIN_AMBIENT,
      :AW_WORLD_TERRAIN_DIFFUSE, :AW_WORLD_WATER_VISIBILITY,
      :AW_WORLD_SOUND_FOOTSTEP, :AW_WORLD_SOUND_WATER_ENTER,
      :AW_WORLD_SOUND_WATER_EXIT, :AW_WORLD_SOUND_AMBIENT, :AW_WORLD_GRAVITY,
      :AW_WORLD_BUOYANCY, :AW_WORLD_FRICTION, :AW_WORLD_WATER_FRICTION,
      :AW_WORLD_SLOPESLIDE_ENABLED, :AW_WORLD_SLOPESLIDE_MIN_ANGLE,
      :AW_WORLD_SLOPESLIDE_MAX_ANGLE, :AW_WORLD_ALLOW_TOURIST_BUILD,
      :AW_WORLD_ENABLE_REFERER, :AW_WORLD_WATER_UNDER_TERRAIN,
      :AW_WORLD_TERRAIN_OFFSET, :AW_WORLD_VOIP_RIGHT,
      :AW_WORLD_DISABLE_MULTIPLE_MEDIA, :AW_WORLD_BOTMENU_URL,
      :AW_WORLD_ENABLE_BUMP_EVENT, :AW_WORLD_ENABLE_SYNC_EVENTS,
      :AW_WORLD_ENABLE_CAV, :AW_WORLD_ENABLE_PAV, :AW_WORLD_CHAT_DISABLE_URL_CLICKS,
      :AW_WORLD_MOVER_EMPTY_RESET_TIMEOUT, :AW_WORLD_MOVER_USED_RESET_TIMEOUT

    event_attributes_for :AW_EVENT_WORLD_DISCONNECT, :AW_DISCONNECT_REASON
    event_attributes_for :AW_EVENT_WORLD_INFO, :AW_WORLDLIST_NAME,
      :AW_WORLDLIST_USERS, :AW_WORLDLIST_STATUS, :AW_WORLDLIST_RATING
  end  

  include AwSDKSupport
  extend AwSDKSupport

end
