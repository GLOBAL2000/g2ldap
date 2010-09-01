#!/usr/bin/ruby                                                                                                                                                                                                

require 'rubygems'
require 'trollop'
require 'active_ldap'
require 'date'

require 'g2ldap-config'
require './g2ldap-library'

SUB_COMMANDS = %w(report check)
global_opts = Trollop::options do
  banner "GLOBAL2000 utility to check expired accounts"
  banner "Usage see INSERT_NAME_HERE #{SUB_COMMANDS.join("|")} --help"
  stop_on SUB_COMMANDS
end


cmd = ARGV.shift
cmd_opts =
  case cmd
  when "report"
    Trollop::options do
    opt :file, "Output file", :type => :string, :default => "~/Desktop/expire_report"
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
  report.each { |r| puts r.join(";") }

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

