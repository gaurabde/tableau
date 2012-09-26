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

class Help < MultiCommand::Command
  def doc
    # we only want to display "pure" help topics here; those not
    # associated with commands.
    topics = MultiCommand::HelpManager.help.reject { |name,topic| topic.command? && topic.list? }
    # insert help back into the topics with an "empty" command
    # so that it appears first and doesn't say "help help"
    topics[""] = self

    max_topic_width = topics.keys.map { |k| k.length }.max

    format = "#{MultiCommand.appname} help %-#{max_topic_width}s -- %s\n"
    summary_text = topics.sort.inject("") do |text, kvpair|
      name, topic = kvpair
      text << format % [name, topic.summary]
    end
    summary_text
  end

  def usage
    "<command> [options]"
  end

  def opts_heading
  end

  def summary
    "Help for #{MultiCommand.appname} commands"
  end

  def define_options(opts,args)
    unless args.first.nil?
      cmd = (MultiCommand::CommandManager.find_command(args.first) rescue nil)
      MultiCommand::HelpManager.format_and_define_options(cmd,opts,args)
    end
  end

  def run(opts,args)
    help_name = args.first || 'help'
    opts.banner = MultiCommand::HelpManager.help_for(help_name)
    MultiCommand::HelpManager.exit_with_help(opts)
  end
end
Help.instance

class CommandHelp < MultiCommand::HelpTopic
  def name
    "<a command>"
  end

  def doc
    "Show help for a specific command."
  end
end
CommandHelp.instance

class Commands < MultiCommand::HelpTopic
  attr_accessor :prefix

  def doc
    commands = MultiCommand::CommandManager.commands.reject { |name,cmd| not cmd.command? or not cmd.list? }
    commands.reject! { |name,cmd| not (name =~ /^#{@prefix}/) } unless @prefix.nil?

    max_command_width = commands.keys.map { |k| k.length }.max
    format = "#{MultiCommand.appname} %-#{max_command_width}s -- %s\n"
    summary_text = commands.sort.inject("") do |text, kvpair|
      name, topic = kvpair
      text << format % [name, topic.summary]
    end

    <<EOM
Available commands:
#{summary_text.chomp}
EOM
  end

  def summary
    "List all available commands"
  end

  def usage
    "<command> [options]"
  end
end
Commands.instance
