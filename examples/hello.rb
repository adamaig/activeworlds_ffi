#! /usr/bin/env ruby19
require 'rubygems'
require 'activeworlds_ffi'

include ActiveworldsFFI

def handle_avatar_add
  s = "Hello #{aw_string(AW_AVATAR_NAME)}! I'm the broken record."
  # we're using a console message instead of aw_say(s) since that might be annoying
  aw_string_set(AW_CONSOLE_MESSAGE, s)
  aw_console_message(aw_int(AW_AVATAR_SESSION))
  puts(s)
end

if ARGV.nil? || ARGV.size < 3
  puts("Usage: hello.rb citizen_id privilege_password world")
  exit(1)
end

# initialize Active Worlds API
rc = aw_init(AW_BUILD)
if( rc != RC_SUCCESS )
  printf("Unable to initialize API (reason %d)\n", rc)
  exit( 1 ) 
end

# assign the proc to a constant so that it never gets garbage collected
AVATAR_ADD_HANDLER = Proc.new { handle_avatar_add }

# install handler for avatar_add event 
aw_event_set(AW_EVENT_AVATAR_ADD, AVATAR_ADD_HANDLER)
  
# create bot instance 
rc = aw_create("atlantis.activeworlds.com", 5870, nil);
if rc != RC_SUCCESS
  printf "Unable to create bot instance (reason %d)\n", rc
  exit 1
end
  
# log bot into the universe 
aw_int_set AW_LOGIN_OWNER, ARGV[0].to_i
aw_string_set AW_LOGIN_PRIVILEGE_PASSWORD, ARGV[1]
aw_string_set AW_LOGIN_APPLICATION, "SDK Sample Application #1"
aw_string_set AW_LOGIN_NAME, "GreeterBot"
rc = aw_login
if rc != RC_SUCCESS
  printf("Unable to login (reason %d)\n", rc)
  exit(1)
end
  
# log bot into the world named on the command line 
rc = aw_enter (ARGV[2]);
if (rc != RC_SUCCESS)
  printf("Unable to enter world (reason %d)\n", rc)
  exit(1)
end
  
# announce our position in the world 
aw_int_set(AW_MY_X, 1000) #/* 1W */
aw_int_set(AW_MY_Z, 1000) #/* 1N */
aw_int_set(AW_MY_YAW, 2250)  #/* face towards GZ */
rc = aw_state_change 
if rc != RC_SUCCESS
  printf "Unable to change state (reason %d)\n", rc
  exit 1
end
  
#  /* main event loop */
while aw_wait(-1) == RC_SUCCESS
end
  
#  /* close everything down */
aw_destroy
aw_term

