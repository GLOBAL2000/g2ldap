#!/usr/bin/ruby                                                                                                                                                                                                

require 'rubygems'
require 'trollop'
require 'active_ldap'
require 'date'

require 'g2ldap-config'
require 'g2ldap-library'

SUB_COMMANDS = %w(report check)
global_opts = Trollop::options do
  banner "GLOBAL2000 utility to check expired accounts"
  banner "Usage see #{$0} #{SUB_COMMANDS.join("|")} --help"
  stop_on SUB_COMMANDS
end

default_out_file = "~/Desktop/g2_expire_report.csv"

cmd = ARGV.shift
cmd_opts =
  case cmd
  when "report"
    Trollop::options do
    opt :file, "Output to file #{default_out_file}"
    opt :name, "File to save report to", :type => :string, :default => default_out_file
  end
  when "check"
    Trollop::options do
    opt :name, "Username", :type => :string
  end
  else
    Trollop::die "unknown subcommand #{cmd.inspect}"
  end

case cmd
when "report"
  report = []
  User.find(:all).collect { |user| report.push gen_report_line(user) }

  report.sort! { |x, y| Date.parse(x.last) <=> Date.parse(y.last) }

  report.unshift ["username","name","info","typ","ablaufdatum"]
  report.unshift ["valid types are: " + $valid_types.keys.join(",") ]
  if cmd_opts[:file_given] or cmd_opts[:name_given] then
    f = File.new(File.expand_path(cmd_opts[:name]), "w") 
    report.each { |r| f.puts r.join(";") }
    f.close
  else
    puts r.join(";") 
  end
  
when "check"
  puts "Folgende user sind bereits abgelaufen: "+get_expired_users().join(",")
  begin
    print "Name des users eintippen, der verlängert werden soll: "
    input = gets.chomp
    extend_user_validity get_user(input) unless input.empty?
  end until input.empty?

  User.find(:all).collect { |user| 
    if check_user_validity(user) then
      extend_user_validity(user)
    end
  }
end

