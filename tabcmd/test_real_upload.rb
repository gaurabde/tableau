require 'tabcmd_gem'
require 'optparse'

publish = MultiCommand::CommandManager.find_command('publish')

opts = OptionParser.new
argv = ['-o',
        '-s' ,'http://10.80.129.167',
        '--username', 'pivotal',
        '--password', '',
        '--db-username', 'gpadmin',
        '--db-password', 'secret',
        '--save-db-password']

MultiCommand::CommandManager.define_options(opts, argv)
publish.define_options(opts, argv)
opts.parse!(argv)
publish.run(opts, ['/Users/pivotal/workspace/tabcmd_gem/sfo_table_workbook.twb'])