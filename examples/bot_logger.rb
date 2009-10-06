require 'rubygems'
require 'yaml'
require 'logger'

class BotLogger < Logger

  def initialize(options={})
    progname = options[:application_name] || 'bot_logger'
    @logfile = File.open(File.join(File.dirname(__FILE__),"logs", "#{progname}.log"), "a")
    @logfile.sync = true

    super(@logfile, options[:rotate_count] || 1, options[:max_size] || 300 * 1024**2 )
    self.progname = progname
    self.level = options[:log_level] || Logger::INFO
    self.formatter = Logger::Formatter.new
    self.datetime_format = "%Y-%m-%d %H:%M:%S"
  end

end


