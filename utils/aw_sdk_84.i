%module aw_sdk_50

%{
require 'rubygems'
require 'ffi'

module ActiveworldsFFI
  extend FFI::Library
  ffi_lib "libstdc++.so.6"
  ffi_lib "libaw_sdk.50.so.84"
  
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
  
end
%}
