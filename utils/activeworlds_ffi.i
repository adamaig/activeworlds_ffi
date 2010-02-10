%module aw_sdk_50

%{
require 'rubygems'
require 'ffi'

module ActiveworldsFFI
  extend FFI::Library
  ffi_lib "libstdc++.so.6"
  ffi_lib "libaw_sdk.50.so.84"
  
  # Reason Codes
  RC_SUCCESS                            = 0
  RC_CITIZENSHIP_EXPIRED                = 1
  RC_LAND_LIMIT_EXCEEDED                = 2
  RC_NO_SUCH_CITIZEN                    = 3
  RC_LICENSE_PASSWORD_CONTAINS_SPACE    = 5
  RC_LICENSE_PASSWORD_TOO_LONG          = 6
  RC_LICENSE_PASSWORD_TOO_SHORT         = 7
  RC_LICENSE_RANGE_TOO_LARGE            = 8
  RC_LICENSE_RANGE_TOO_SMALL            = 9
  RC_LICENSE_USERS_TOO_LARGE            = 10
  RC_LICENSE_USERS_TOO_SMALL            = 11
  RC_INVALID_PASSWORD                   = 13
  RC_LICENSE_WORLD_TOO_SHORT            = 15
  RC_LICENSE_WORLD_TOO_LONG             = 16
  RC_INVALID_WORLD                      = 20
  RC_SERVER_OUTDATED                    = 21
  RC_WORLD_ALREADY_STARTED              = 22
  RC_NO_SUCH_WORLD                      = 27
  RC_UNAUTHORIZED                       = 32
  RC_WORLD_ALREADY_EXISTS               = 33
  RC_NO_SUCH_LICENSE                    = 34
  RC_TOO_MANY_WORLDS                    = 57
  RC_MUST_UPGRADE                       = 58
  RC_BOT_LIMIT_EXCEEDED                 = 59
  RC_WORLD_EXPIRED                      = 61
  RC_CITIZEN_DOES_NOT_EXPIRE            = 62
  RC_LICENSE_STARTS_WITH_NUMBER         = 64
  RC_NO_SUCH_EJECTION                   = 66
  RC_NO_SUCH_SESSION                    = 67
  RC_WORLD_RUNNING                      = 72
  RC_WORLD_NOT_SET                      = 73
  RC_NO_SUCH_CELL                       = 74
  RC_NO_REGISTRY                        = 75
  RC_CANT_OPEN_REGISTRY                 = 76
  RC_CITIZEN_DISABLED                   = 77
  RC_WORLD_DISABLED                     = 78
  RC_TELEGRAM_BLOCKED                   = 85
  RC_UNABLE_TO_UPDATE_TERRAIN           = 88
  RC_EMAIL_CONTAINS_INVALID_CHAR        = 100
  RC_NO_SUCH_OBJECT                     = 101
  RC_NOT_DELETE_OWNER                   = 102
  RC_EMAIL_MISSING_AT                   = 103
  RC_EMAIL_STARTS_WITH_BLANK            = 104
  RC_EMAIL_TOO_LONG                     = 105
  RC_EMAIL_TOO_SHORT                    = 106
  RC_NAME_ALREADY_USED                  = 107
  RC_NAME_CONTAINS_NONALPHANUMERIC_CHAR = 108
  RC_NAME_CONTAINS_INVALID_BLANK        = 109
  RC_NAME_ENDS_WITH_BLANK               = 111
  RC_NAME_TOO_LONG                      = 112
  RC_NAME_TOO_SHORT                     = 113
  RC_PASSWORD_TOO_LONG                  = 115
  RC_PASSWORD_TOO_SHORT                 = 116
  RC_UNABLE_TO_DELETE_CITIZEN           = 124
  RC_NUMBER_ALREADY_USED                = 126
  RC_NUMBER_OUT_OF_RANGE                = 127
  RC_PRIVILEGE_PASSWORD_IS_TOO_SHORT    = 128
  RC_PRIVILEGE_PASSWORD_IS_TOO_LONG     = 129
  RC_NOT_CHANGE_OWNER                   = 203
  RC_CANT_FIND_OLD_ELEMENT              = 204
  RC_IMPOSTER                           = 212
  RC_ENCROACHES                         = 300
  RC_OBJECT_TYPE_INVALID                = 301
  RC_TOO_MANY_BYTES                     = 303
  RC_UNREGISTERED_OBJECT                = 306
  RC_ELEMENT_ALREADY_EXISTS             = 308
  RC_RESTRICTED_COMMAND                 = 309
  RC_OUT_OF_BOUNDS                      = 311
  RC_RESTRICTED_OBJECT                  = 313
  RC_RESTRICTED_AREA                    = 314
  RC_NOT_YET                            = 401
  RC_TIMEOUT                            = 402
  RC_UNABLE_TO_CONTACT_UNIVERSE         = 404
  RC_NO_CONNECTION                      = 439
  RC_NOT_INITIALIZED                    = 444
  RC_NO_INSTANCE                        = 445
  RC_INVALID_ATTRIBUTE                  = 448
  RC_TYPE_MISMATCH                      = 449
  RC_STRING_TOO_LONG                    = 450
  RC_READ_ONLY                          = 451
  RC_INVALID_INSTANCE                   = 453
  RC_VERSION_MISMATCH                   = 454
  RC_QUERY_IN_PROGRESS                  = 464
  RC_EJECTED                            = 466
  RC_NOT_WELCOME                        = 467
  RC_CONNECTION_LOST                    = 471
  RC_NOT_AVAILABLE                      = 474
  RC_CANT_RESOLVE_UNIVERSE_HOST         = 500
  RC_INVALID_ARGUMENT                   = 505
  RC_UNABLE_TO_UPDATE_CAV               = 514
  RC_UNABLE_TO_DELETE_CAV               = 515
  RC_NO_SUCH_CAV                        = 516
  RC_WORLD_INSTANCE_ALREADY_EXISTS      = 521
  RC_WORLD_INSTANCE_INVALID             = 522
  RC_PLUGIN_NOT_AVAILABLE               = 523
  RC_DATABASE_ERROR                     = 600
  RC_Z_BUF_ERROR                        = 4995
  RC_Z_MEM_ERROR                        = 4996
  RC_Z_DATA_ERROR                       = 4997


   
   # This has all the strings for the reason codes
   RC_DICTIONARY = {
     RC_SUCCESS                            => "Success",
     RC_CITIZENSHIP_EXPIRED                => "Citizenship has expired: Citizenship of the owner has expired.",
     RC_LAND_LIMIT_EXCEEDED                => "Land limit exceeded: Land limit of the universe would be exceeded if the world is started.",
     RC_NO_SUCH_CITIZEN                    => "No such citizen: No citizenship with a matching citizen number was found.",
     RC_LICENSE_PASSWORD_CONTAINS_SPACE    => "License password contains space: Password cannot contain a space.",
     RC_LICENSE_PASSWORD_TOO_LONG          => "License password too long:  Password cannot be longer than 8 characters.",
     RC_LICENSE_PASSWORD_TOO_SHORT         => "License password too short: Password must be at least 2 characters.",
     RC_LICENSE_RANGE_TOO_LARGE            => "License range too large: Range must be smaller than 3275 hectometers. That is, at most 32750 coordinates N/S/W/E or 655000 meters across.",
     RC_LICENSE_RANGE_TOO_SMALL            => "License range too small: Range must be larger than 0 hectometers. That is, at least 10 coordinates N/S/W/E or 200 meters across.",
     RC_LICENSE_USERS_TOO_LARGE            => "License users too large: User limit cannot exceed 1024.",
     RC_LICENSE_USERS_TOO_SMALL            => "License users too small: User limit must be larger than 0.",
     RC_INVALID_PASSWORD                   => "Invalid password: Unable to login due to invalid password.",
     RC_LICENSE_WORLD_TOO_SHORT            => "License world too short: Name must be at least 2 characters.",
     RC_LICENSE_WORLD_TOO_LONG             => "License world too long: Name cannot be longer than 8 characters.",
     RC_INVALID_WORLD                      => "Invalid world: Unable to start the world due to invalid name or password.",
     RC_SERVER_OUTDATED                    => "Server outdated: Server build either contains a serious flaw or is outdated and must be upgraded.",
     RC_WORLD_ALREADY_STARTED              => "World already started: World has already been started at a different location.",
     RC_NO_SUCH_WORLD                      => "No such world: No world with a matching name has been started on the server.",
     RC_UNAUTHORIZED                       => "Unauthorized: Not authorized to perform the operation.",
     RC_WORLD_ALREADY_EXISTS               => "World already exists: TODO: Might not be in use.",
     RC_NO_SUCH_LICENSE                    => "No such license: No license with a matching world name was found.",
     RC_TOO_MANY_WORLDS                    => "Too many worlds: Limit of started worlds in the universe would be exceeded if the world is started.",
     RC_MUST_UPGRADE                       => "Must upgrade: SDK build either contains a serious flaw or is outdated and must be upgraded.",
     RC_BOT_LIMIT_EXCEEDED                 => "Bot limit exceeded: Bot limit of the owner citizenship would be exceeded if the bot is logged in.",
     RC_WORLD_EXPIRED                      => "World expired: Unable to start world due to its license having expired.",
     RC_CITIZEN_DOES_NOT_EXPIRE            => "Citizen does not expire: TODO: What is this used for?",
     RC_LICENSE_STARTS_WITH_NUMBER         => "License starts with number: Name cannot start with a number.",
     RC_NO_SUCH_EJECTION                   => "No such ejection: No ejection with a matching identifier was found.",
     RC_NO_SUCH_SESSION                    => "No such session: No user with a matching session number has entered the world.",
     RC_WORLD_RUNNING                      => "World running: World has already been started.",
     RC_WORLD_NOT_SET                      => "World not set: World to perform the operation on has not been set.",
     RC_NO_SUCH_CELL                       => "No such cell: No more cells left to enumerate.",
     RC_NO_REGISTRY                        => "No registry: Unable to start world due to missing or invalid registry.",
     RC_CANT_OPEN_REGISTRY                 => "Can't open registry",
     RC_CITIZEN_DISABLED                   => "Citizen disabled: Citizenship of the owner has been disabled.",
     RC_WORLD_DISABLED                     => "World disabled: Unable to start world due to it having been disabled.",
     RC_TELEGRAM_BLOCKED                   => "Telegram blocked",
     RC_UNABLE_TO_UPDATE_TERRAIN           => "Unable to update terrain",
     RC_EMAIL_CONTAINS_INVALID_CHAR        => "Email contains invalid char: Email address contains one or more invalid characters.",
     RC_NO_SUCH_OBJECT                     => "No such object: Unable to find the object to delete.",
     RC_NOT_DELETE_OWNER                   => "Not delete owner",
     RC_EMAIL_MISSING_AT                   => "Email missing at: Email address must contain a '@'.",
     RC_EMAIL_STARTS_WITH_BLANK            => "Email starts with blank: Email address cannot start with a blank.",
     RC_EMAIL_TOO_LONG                     => "Email too long: Email address cannot be longer than 50 characters.",
     RC_EMAIL_TOO_SHORT                    => "Email too short: Email address must be at least 8 characters or longer.",
     RC_NAME_ALREADY_USED                  => "Name already used: Citizenship with a matching name already exists.",
     RC_NAME_CONTAINS_NONALPHANUMERIC_CHAR => "Name contains nonalphanumeric character: Name contains invalid character(s).",
     RC_NAME_CONTAINS_INVALID_BLANK        => "Name contains invalid blank: Name contains invalid blank(s).",
     RC_NAME_ENDS_WITH_BLANK               => "Name ends with blank: Name cannot end with a blank.",
     RC_NAME_TOO_LONG                      => "Name too long: Name cannot be longer than 16 characters.",
     RC_NAME_TOO_SHORT                     => "Name too short: Name must be at least 2 characters.",
     RC_PASSWORD_TOO_LONG                  => "Password too long: Password cannot be longer than 12 characters.",
     RC_PASSWORD_TOO_SHORT                 => "Password too short: Password must be at least 4 characters.",
     RC_UNABLE_TO_DELETE_CITIZEN           => "Unable to delete citizen: Unable to delete citizen due to a database problem.",
     RC_NUMBER_ALREADY_USED                => "Number already used: Citizenship with a matching citizen number already exists.",
     RC_NUMBER_OUT_OF_RANGE                => "Number out of range: Citizen number is larger than the auto-incremented field in the database.",
     RC_PRIVILEGE_PASSWORD_IS_TOO_SHORT    => "Privilege password is too short: Privilege password must be either empty or at least 4 characters.",
     RC_PRIVILEGE_PASSWORD_IS_TOO_LONG     => "Privilege password is too long: Password cannot be longer than 12 characters.",
     RC_NOT_CHANGE_OWNER                   => "Not change owner: Not permitted to change the owner of an object. It requires eminent domain or caretaker capability.",
     RC_CANT_FIND_OLD_ELEMENT              => "Can't find old element: Unable to find the object to change.",
     RC_IMPOSTER                           => "Imposter: Unable to enter world due to masquerading as someone else.",
     RC_ENCROACHES                         => "Encroaches: Not allowed to encroach into another's property.",
     RC_OBJECT_TYPE_INVALID                => "Object type invalid",
     RC_TOO_MANY_BYTES                     => "Too many bytes: Cell limit would be exceeded.",
     RC_UNREGISTERED_OBJECT                => "Unregistered object: Model name does not exist in the registry.",
     RC_ELEMENT_ALREADY_EXISTS             => "Element already exists",
     RC_RESTRICTED_COMMAND                 => "Restricted command",
     RC_OUT_OF_BOUNDS                      => "Out of bounds",
     RC_RESTRICTED_OBJECT                  => "Restricted object: Not allowed to build with 'z' objects in this world.",
     RC_RESTRICTED_AREA                    => "Restricted area: Not allowed to build within the restricted area of this world.",
     RC_NOT_YET                            => "Not yet: Would exceed the maximum number of operations per second.",
     RC_TIMEOUT                            => "Timeout: Synchronous operation timed out.",
     RC_UNABLE_TO_CONTACT_UNIVERSE         => "Unable to contact universe: Unable to establish a connection to the universe server.",
     RC_NO_CONNECTION                      => "No connection: Connection to the server is down.",
     RC_NOT_INITIALIZED                    => "Not initialized: SDK API has not been initialized (by calling aw_init).",
     RC_NO_INSTANCE                        => "No instance",
     RC_INVALID_ATTRIBUTE                  => "Invalid attribute",
     RC_TYPE_MISMATCH                      => "Type mismatch",
     RC_STRING_TOO_LONG                    => "String too long",
     RC_READ_ONLY                          => "Read only: Unable to set attribute due to it being read-only.",
     RC_INVALID_INSTANCE                   => "Invalid instance",
     RC_VERSION_MISMATCH                   => "Version mismatch: Aw.h and Aw.dll (or libaw_sdk.so for Linux) are from different builds of the SDK.",
     RC_QUERY_IN_PROGRESS                  => "Query in progress: A property query is already in progress.",
     RC_EJECTED                            => "Ejected: Disconnected from world due to ejection.",
     RC_NOT_WELCOME                        => "Not welcome: Citizenship of the owner does not have bot rights in the world.",
     RC_CONNECTION_LOST                    => "Connection lost",
     RC_NOT_AVAILABLE                      => "Not available",
     RC_CANT_RESOLVE_UNIVERSE_HOST         => "Can't resolve universe host",
     RC_INVALID_ARGUMENT                   => "Invalid argument",
     RC_UNABLE_TO_UPDATE_CAV               => "Unable to update custom avatar",
     RC_UNABLE_TO_DELETE_CAV               => "Unable to delete custom avatar",
     RC_NO_SUCH_CAV                        => "No such custom avatar",
     RC_WORLD_INSTANCE_ALREADY_EXISTS      => "World instance already exists",
     RC_WORLD_INSTANCE_INVALID             => "World instance invalid",
     RC_PLUGIN_NOT_AVAILABLE               => "Plugin not available",
     RC_DATABASE_ERROR                     => "Database error",
     RC_Z_BUF_ERROR                        => "Buffer error (zlib)Not enough room in the output buffer.",
     RC_Z_MEM_ERROR                        => "Memory error (zlib): Memory could not be allocated for processing.",
     RC_Z_DATA_ERROR                       => "Data error (zlib): Input data was corrupted."
   }
   
%}


%include "Aw.h"

%{
  attach_function :aw_data, [:int, :buffer_out], :pointer
  attach_function :aw_user_data_set, [:buffer_inout], :int
  # these take as the pointer a int[3][3] or int[5][5] respectively
  attach_function :aw_query, [:int, :int, :buffer_inout], :int
  attach_function :aw_query_5x5, [:int, :int, :buffer_inout], :int
  attach_function :aw_world_attribute_set, [:int, :buffer_in], :int
  attach_function :aw_world_attribute_get, [:int, :buffer_out, :buffer_out], :int
  
  alias :aw_string_set_ffi :aw_string_set
  alias :aw_data_set_ffi   :aw_data_set  
  alias :aw_bool_set_ffi   :aw_bool_set
  alias :aw_bool_ffi       :aw_bool

  def aw_bool_set(attribute, tf)
    aw_bool_set_ffi(attribute, tf ? 1 : 0)
  end

  def aw_bool(attribute)
    aw_bool_ffi(attribute) == 1 ? true : false
  end

  def aw_string_set(aw_attr,str,length=AW_MAX_ATTRIBUTE_LENGTH)
    aw_string_set_ffi(aw_attr,str[0,length])
  end

  def aw_data_set(aw_attr,data_buffer,length=AW_MAX_DATA_ATTRIBUTE_LENGTH)
    base_aw_data_set(aw_attr,data_buffer[0,length],
      length > AW_MAX_DATA_ATTRIBUTE_LENGTH ? AW_MAX_DATA_ATTRIBUTE_LENGTH : length )
  end

  # looks up the return code explanation
  def rc_string(rc)
    RC_DICTIONARY[rc]
  end
end
%}
