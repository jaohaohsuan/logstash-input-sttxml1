# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"
require "socket" # for Socket.gethostname
require "filewatcher"
require "nokogiri"

# Generate a repeating message.
#
# This plugin is intented only as an example.

class LogStash::Inputs::Sttxml1 < LogStash::Inputs::Base
  config_name "sttxml1"

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "plain" 

	# Default matches R0 and r0
	config :agent_regex, :validate => :string, :default => '[rR]0'

	# Default matches R1 and r1
	config :customer_regex, :validate => :string, :default => '[rR]1'

	# The path(s) to the file(s) to use as an input.
	config :path, :validate => :array, :required => true 

	# How often (in seconds) we stat files to see if they have been modified.
  # Increasing this interval will decrease the number of system calls we make,
  # but increase the time to detect new log lines.
  config :stat_interval, :validate => :number, :default => 3

  public
  def register
    @host = Socket.gethostname
		@logger.info("Registering file input", :path => @path)
  end # def register

  def run(queue)
		FileWatcher.new(@path).watch(@stat_interval) do |filename, event|
			if(event == :new)
				
				agentRegex = /#{@agent_regex}/
      	customerRegex = /#{@customer_regex}/
      	agentParties = 0
      	customerParties = 0
      	parties = Hash.new

				begin
					value = File.read(filename)
       		doc = Nokogiri::XML(value, nil, value.encoding.to_s)
        	clauses = []
        	event = LogStash::Event.new("host" => @host)
					
					doc.xpath("//Subject[@Name='RecognizeText']/Role").each do |link|
						who = "#{link.attribute('Name').content}"
						if(who=~agentRegex)
							if(!parties.key?(who))
								parties[who] = "agent#{agentParties}"
								agentParties += 1
							end
						end

						if(who=~customerRegex)
							if(!parties.key?(who))
								parties[who] = "customer#{customerParties}"
								customerParties += 1
							end
						end
						party = parties[who]
						event[party] = ''
						link.child.children.each do |item|
							begin_time, end_time, content = item.attribute('Begin').content.to_i, item.attribute('End').content.to_i, item.child.text
							event[party] += "#{party}-#{begin_time} #{content}\n"
							clauses << [ who, party, begin_time, end_time, content ]
						end
						event['parties'] = parties.keys
						event['dialogs'] =	clauses.sort_by { |_, _, begin_time, _, _| begin_time }.map { |_, party, begin_time, _, content| "#{party}-#{begin_time} #{content}" }.join("\n")
						event['vtt'] =	(clauses.sort_by { |_, _, begin_time, _, _| begin_time }.map do |who, party, begin_time, end_time, content| 
							"#{party}-#{begin_time}\n#{Time.at(begin_time/1000).utc.strftime('%H:%M:%S.')}#{'%.3d' % (begin_time%1000)} --> #{Time.at(end_time/1000).utc.strftime('%H:%M:%S.')}#{'%.3d' %(end_time%1000)}\n<v #{who}>#{content}</v>\n"
						end)
					end

	      	decorate(event)
      		queue << event
				rescue => ex
					@logger.warn('Trouble parsing xml', :source => @source, :exception => ex, :backtrace => ex.backtrace)
        	return
				end
			end      
		end

  end # def run

end # class LogStash::Inputs::Sttxml1
