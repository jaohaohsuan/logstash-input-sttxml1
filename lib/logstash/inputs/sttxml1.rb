# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"
require "socket" # for Socket.gethostname
require "filewatcher"

# Generate a repeating message.
#
# This plugin is intented only as an example.

class LogStash::Inputs::Sttxml1 < LogStash::Inputs::Base
  config_name "sttxml1"

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "plain" 

	# The path(s) to the file(s) to use as an input.
	config :path, :validate => :array, :required => true 

  public
  def register
    @host = Socket.gethostname
		@logger.info("Registering file input", :path => @path)
  end # def register

  def run(queue)
		FileWatcher.new(@path).watch do |filename|
      event = LogStash::Event.new("message" => filename, "host" => @host)
      decorate(event)
      queue << event
		end

  end # def run

end # class LogStash::Inputs::Sttxml1
