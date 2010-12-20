#!/usr/bin/ruby

require 'rubygems'
require 'trollop'
require 'active_ldap'

require 'g2ldap-config'
require 'g2ldap-library'

# Trollop option to ActiveLDAP name mapper
t_to_al = {
  :name =>  "uid",
  :uid => "uid_number",
  :gid => "gid_number",
  :givenname => "given_name",
  :surname => "sn",
  :mail => "mail",
  :home => "home_directory",
  :shell => "login_shell",
  :expires => "car_license",
  :teams => "department_number",
  :type => "employee_type",
  :description => "description",
  :password => "user_password",
}

user_attributes = Hash.new

SUB_COMMANDS = %w(add del mod ls)
global_opts = Trollop::options do
  banner "GLOBAL2000 utility for LDAP users"
  banner "Usage see #{$0} #{SUB_COMMANDS.join("|")} --help"
  stop_on SUB_COMMANDS
end


cmd = ARGV.shift
cmd_opts = 
  case cmd
  when "del"
    Trollop::options do
    opt :name, "Username", :type => :string
  end
  when "add", "mod"
    Trollop::options do
    opt :name, "Username", :type => :string
    opt :uid, "UID Number, defaults to highest existing uid+1", :type => :integer
    opt :gid, "GID Number, default to 100", :type => :integer
    opt :givenname, "Given name", :type => :string
    opt :surname, "Surname", :type => :string
    opt :mail, "Mail address", :type => :string
    opt :home, "Home directory", :type => :string
    opt :shell, "Login shell", :type => :string
    opt :groups, "Groups for the user, ATTENTION user will be removed from all other groups", :type => :strings
    opt :add_groups, "Groups for the user to added to", :type => :strings
    opt :remove_groups, "Remove user from these groups", :type => :strings
    opt :expires, "Months till user invalidates", :type => :integer
    opt :type, "Employment, valid values are: " + $valid_types.keys.join(","), :type => :string
    opt :description, "Any describing text you want", :type => :string
    opt :password, "User Password, defaults to using SASL/Kerberos", :type => :string
    opt :noop, "Do not actually save the user", :default => false
  end
  when "ls"
    Trollop::options do
    opt :name, "Username", :type => :string
  end
  else
    Trollop::die "unknown subcommand #{cmd.inspect}"
  end

Trollop::die :groups, "must not be given in combination with add-groups or remove-groups" if (cmd_opts[:add_groups_given] || cmd_opts[:remove_groups_given]) && cmd_opts[:groups]
Trollop::die :name, "must be given" unless cmd_opts[:name_given]
Trollop::die :type, "employment type must be given" if ( !cmd_opts[:type] && cmd == "add" )
Trollop::die :type, "invalid employment type given" unless ($valid_types.include?(cmd_opts[:type])) if cmd_opts[:type]

case cmd
when "add"
  user = get_user(cmd_opts[:name], false)

  user_attributes = map_user_hash(cmd_opts, t_to_al, user)
  parse_new_user_default(user_attributes, t_to_al)
  mod_obj( user, user_attributes )
when "mod"
  user = get_user(cmd_opts[:name])

  user_attributes = map_user_hash(cmd_opts, t_to_al, user)
  mod_obj( user, user_attributes )
when "del"
  get_user(cmd_opts[:name])
  User.destroy(cmd_opts[:name])
when "ls"
  user = get_user(cmd_opts[:name])
  puts user.to_ldif

  groups = []
  primary_group = user.primary_group
  if primary_group.exists?
    groups << "#{primary_group.cn}[#{primary_group.gid_number}]"
  end
  puts "Groups by name only: #{user.groups(false).join(', ')}"
  user.groups.sort_by do |group|
    group.id
  end.collect do |group|
    groups << "#{group.cn}[#{group.gid_number}]"
  end
  puts "Groups: #{groups.join(', ')}"
end

unless cmd_opts[:noop] or cmd == "del" then
  user.save
  save_groups_for_user( user, cmd_opts )
end
