# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2011 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
#
# Portions of the code
# Copyright (c) 2002 The Board of Trustees of the Leland Stanford
#                    Junior University. All rights reserved.
# -----------------------------------------------------------------------

require 'enumerator'
require 'optparse'
require 'pathname'
require 'singleton'
require 'rchardet'
require 'iconv'

require 'multicommand/exceptions'
require 'support'

module MultiCommand
  mattr_accessor :appname
  self.appname = "tabcmd"

  # The parent class for help topics registered with HelpManager
  class HelpTopic
    include Singleton

    def name
      self.class.name.downcase
    end

    def initialize
      HelpManager.register(self) if list?
    end

    def opts_heading
      "Command options:"
    end

    def doc
      raise NotImplementedError, "#{self.class.name} children must implement #doc"
    end

    # The summary is auto-extracted from the first sentence in the
    # first line of the doc string. is the one-line command summary.
    # The summary sentence may not contain a newline.
    def summary
      doc.each { |line| return (line.match(/([^\.]*)\.\s?/)[1] rescue "Error in #{self.class.name}#summary") }
    end

    def usage
      "<command> [options]"
    end

    def command?
      false
    end

    # Show in the command list?
    def list?
      true
    end
  end

  # The parent class for commands registered with CommandManager
  class Command < HelpTopic
    def initialize
      CommandManager.register(self)
      super
    end

    def usage
      "#{name} [options]"
    end

    # opts is an OptionParser instance
    def define_options(opts,args)
    end

    # opts is an OptionParser instance, args are the left-over command-line arguments
    def run(opts,args)
      raise NotImplementedError, "#{self.class.name} children must implement #run"
    end

    def run_each(method, args, *addl)
      failures  = 0
      args.each do |arg|
        begin
          self.send(method, arg, *addl)
        rescue RuntimeError => ex
          logger.error ex.message
          failures += 1
        end
      end
      if failures > 0
        raise MultiCommand::ExitWithStatus, failures
      end
    end

    def command?
      true
    end
  end

  module CommandManager
    class << self
      attr_accessor :appname
      attr_reader :current_command, :commands

      def find_command(name)
        key, cmd = commands.match(name.downcase)
        cmd
      end

      def register(cmd)
        @commands ||= OptionParser::CompletingHash.new
        raise ArgumentError, "Command #{cmd.name} already registered." unless commands[cmd.name].nil?
        commands[cmd.name] = cmd
      end

      def dispatch(argv)
        logger.debug "run as: #{MultiCommand.appname} #{cleanse_argv(argv).join(' ')}"

        opts = OptionParser.new
        @current_command = commands['help']

        if not ( argv.empty? or ['-h','--help'].include?(argv.first) )
          cmd = nil
          name = argv.shift
          begin
            @current_command = find_command(name)
            opts.banner = HelpManager.help_for(name)
          rescue OptionParser::AmbiguousArgument => ex
            logger.error "Command abbreviation '#{name}' is ambiguous.\n"
            opts.banner = HelpManager.commands_like(name)
            @current_command = nil
          end
        end

        begin
          define_options(opts,argv)
          HelpManager.exit_with_help(opts, 1) if current_command.nil?
          argv = argv.map do |arg|
            if arg =~ /^-([A-Z])/
              arg.downcase
            else
              arg
            end
          end
          opts.parse!(argv)

          # BUGZID 21225 -- Error handling when issuing multiple commands from
          # one command line is too confusing, so disable it.
          if argv.size > 1
            raise MultiCommand::HelpError, "#{current_command.name} only accepts a single argument."
          end

          current_command.run(opts,argv)
        rescue OptionParser::MissingArgument => ex
          failed_option = ex.message.match(/(-|--)\w+/)[0]
          logger.error "Missing argument to option #{failed_option}:\n"
          HelpManager.exit_with_help(opts, 1)
        rescue OptionParser::InvalidOption => ex
          failed_option = ex.message.match(/(-|--)\w+/)[0]
          logger.error "Invalid option \"#{failed_option}\" given.\n"
          HelpManager.exit_with_help(opts, 1)
        rescue MultiCommand::HelpError  => ex
          logger.error format_message("Error: ",ex.message) << "\n"
          HelpManager.exit_with_help(opts, 1)
        rescue MultiCommand::ExitWithStatus => ex
          logger.debug "Received ExitWithStatus, code #{ex.status}"
          logger.debug ex.backtrace.join("\n")
          exit ex.status
        rescue MultiCommand::ReportableError => ex
          logger.error format_message("Error: ",ex.message) << "\n"
          exit 1
        rescue SystemExit
          raise # pass SystemExit through
        rescue Exception => ex
          logger.fatal ex.message
          logger.debug ex.backtrace.join("\n")
          exit 1
        end
      end

      def define_options(opts,argv)
        # Define command-specific options
        HelpManager.format_and_define_options(current_command,opts,argv)
        # Define global options
        opts.separator "\nGlobal options:"
        opts.on("-h","--help", "Display #{MultiCommand.appname} help.") do
          argv.unshift current_command.name unless current_command.nil?
          @current_command = commands['help']
        end
        opts.on("-s",
                "--server URL",
                "Use the specified Tableau Server URL.") do |url|
          Server.base_url = url
        end
        opts.on("-u",
                "--username USER",
                "Use the specified Tableau Server username.") do |username|
          Server.username = username
        end
        opts.on("-p",
                "--password PASSWORD",
                "Use the specified Tableau Server password.") do |password|
          Server.password = password
        end
        opts.on("--password-file FILE",
                "Read the Tableau Server password from FILE.") do |path|
          File.open(RelativePath.fix_path(path), "rb") do |file|
            password = file.readline.strip

            #clean the file of BOM if file is UTF
            password = password.unpack("U*")
            password.shift if password[0] == 65279
            password = password.pack("C*")
            Server.password = password
          end
        end
        opts.on("-t",
          "--site SITEID",
          "Use the specified Tableau Server site.") do |site_id|
          Server.site_namespace = site_id
        end
        opts.on("-x",
                "--proxy HOST:PORT",
                /[^:]*:[0-9]*/,
                "Use the specified HTTP proxy.") do |proxy|
          # Note that the regexps above and below differ only in the
          # ()-groups -- Optparse doesn't want them but the line below needs them
          proxy =~ /([^:]*):([0-9]*)/
          Server.proxy_host, Server.proxy_port = $1, $2
        end
        opts.on("--no-prompt",
                "Don't prompt for a password.") do
        Server.no_prompt = true
        end
        opts.on("--no-proxy",
                "Do not use a HTTP proxy.") do
          Server.proxy_host, Server.proxy_port = nil, nil
        end
        opts.on("--[no-]cookie",
                <<EOM
Save the session id on login.
                                     Subsequent commands will not need to
                                     log in.
                                     Default: --cookie.
EOM
               ) do |val|
          Server.save_cookie = val
        end
        opts.on("--timeout SECONDS",
                /[0-9]*/,
                <<EOM
Wait SECONDS for the server
                                     to complete processing the command.
                                     Default: 30
EOM
              ) do |val|
          Server.timeout = val.to_i
        end
      end

      def load_commands(exclusions = [])
        unless $JAVA_WAR
          command_list = Dir[File.dirname(__FILE__)+'/commands/*.rb']
        else
          command_path = Regexp.escape(File.dirname(__FILE__) + "/commands/")
          command_regex = /#{command_path}[^\/]+\.rb$/
          command_list = []
          ExerbRuntime.archive_paths.enum_with_index.each do |p,i|
            command_list << ExerbRuntime.archive_names[i] if p =~ command_regex
          end
        end

        command_list.each do |f|
          command_class_name = File.basename(f).match(/(.*?)\.rb/)[1].gsub(/(^|_)(.)/) { $2.upcase }
          next if exclusions.include?(command_class_name)
          require f
          # Construct the command class' name
          # Create an instance of the command to register it
          Object.const_get(command_class_name).instance
        end
      end

      def format_message(heading,message)
        indent = " " * heading.length
        retval = ""
        message.each_line do |l|
          retval << "#{(retval.empty? ? heading : indent)}#{l}"
        end
        retval.rstrip!
        retval
      end

      def cleanse_argv(argv)
        # Quick parse of argv to pull password out before logging
        clean = []
        idx = 0
        while idx < argv.size
          arg = argv[idx]; idx += 1
          unless (arg == '-p'|| arg == '--password')
            clean.push(arg)
          else
            clean.push(arg)
            clean.push("********") # Add a dummy password to the log
            idx += 1               # skip past the password
          end
        end
        clean
      end

    end # << self
  end

  module HelpManager
    class << self
      attr_reader :help
      attr_accessor :outf

      def find_help(name)
        key, topic = self.help.match(name.downcase)
        topic
      end

      def register(topic)
        @help ||= OptionParser::CompletingHash.new
        help[topic.name] = topic
      end

      # Return help commands for topics matching the abbreviation
      def commands_like(abbrev)
        Commands.instance.prefix = abbrev
        HelpManager.help_for('commands')
      end

      def format_and_define_options(cmd,opts,args)
        unless cmd.nil?
          opts.separator cmd.opts_heading unless cmd.opts_heading.nil?
          cmd.define_options(opts,args)
          opts.separator "" unless cmd.opts_heading.nil?
        end
      end

      # Return help for a specific command or help topic
      def help_for(topic_name,only_commands=false)
        help_text = ""
        topic = (find_help(topic_name) rescue nil)
        if topic.nil? or (only_commands and not topic.command?)
          help_text << "Unknown command: #{topic_name}\n"
          topic = help['help']
        end
        prefixed_usage = topic.usage.enum_for(:each_line).map { |l| "#{MultiCommand.appname} #{l}" }
        usage = CommandManager.format_message("Usage: ","#{prefixed_usage}")
        help_text << <<EOM
Tableau Server Command Line Utility -- Version #{ProductVersion.full.str}

#{topic.doc}
#{usage}

EOM
      end

      def exit_with_help(opts, errcode=0)
        outf.puts opts
        exit errcode
      end
    end # << self
    self.outf = $stderr
  end
end

require 'multicommand/help'
