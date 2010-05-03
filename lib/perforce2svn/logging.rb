require 'rubygems'
require 'log4r'

module Perforce2Svn
  # A convenient module for mixins that allow to
  # share the logging configuration everywhere
  # easily
  module Logging
    @@log = nil

    def Logging.configure(debug)
      if not @@log.nil?
        @@log = Log4r::Logger.new 'perforce2svn'
        @@log.outputters = Log4r::Outputter.stderr
        @@log.level = Log4r::WARN
        Log4r::Outputter.stderr.formatter = Log4r::PatternFormatter.new(:pattern => "[%l]\t%M")
        
        @@log.level = debug ? Log4r::DEBUG : Log4r::INFO
      end
    end
    
    def Logging.log
      @@log ||= Log4r::Logger.root
    end
    
    # Meant for mixing into other classes for simplified logging
    def log
      @@log ||= Log4r::Logger.root
    end
  end
end
