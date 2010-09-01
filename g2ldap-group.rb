#!/usr/bin/ruby

require 'rubygems'
require 'trollop'
require 'active_ldap'

require 'g2ldap-config'
require 'g2ldap-library'

t_to_al = {
  :name =>  "cn",
  :gid => "gid_number",
}

SUB_COMMANDS = %w(add del mod ls)
global_opts = Trollop::options do
  banner "GLOBAL2000 utility for LDAP groups"
  banner "Usage see  #{$0} #{SUB_COMMANDS.join("|")} --help"
  stop_on SUB_COMMANDS
end

cmd = ARGV.shift
cmd_opts = 
  case cmd
  when "del"
    Trollop::options do
    opt :name, "Groupname", :type => :string
  end
  when "add", "mod"
    Trollop::options do
    opt :name, "Groupname", :type => :string
    opt :gid, "GID Number", :type => :integer
    opt :members, "Members for the group, ATTENTION current members get removed first", :type => :strings
    opt :add_members, "Add members to group", :type => :strings
    opt :remove_members, "Remove members from group", :type => :strings
  end
  when "ls"
    Trollop::options do
    opt :name, "Groupname", :type => :string
  end
  else
    Trollop::die "unknown subcommand #{cmd.inspect}"
  end

Trollop::die :users, "must not be given in combination with add-groups or remove-groups" if (cmd_opts[:add_users_given] || cmd_opts[:remove_users_given]) && cmd_opts[:users]
Trollop::die :name, "must be given" unless cmd_opts[:name_given]

case cmd
when "add"
  group = get_group( cmd_opts[:name], false)
  group_attributes = map_group_hash( cmd_opts, t_to_al, group )
  parse_new_group_default(group_attributes, t_to_al)

  mod_obj( group, group_attributes )
  save_members_for_group( group, cmd_opts )
when "mod"
  group = get_group( cmd_opts[:name])
  group_attributes = map_group_hash( cmd_opts, t_to_al, group )

  mod_obj( group, group_attributes)
  save_members_for_group( group, cmd_opts )
when "del"
  group = get_group( cmd_opts[:name])
  group.delete
when "ls"
  group = get_group( cmd_opts[:name])
  members = []
  group.primary_members.each do |mem|
    members << "#{mem.uid}[#{mem.uidNumber}]"
  end
  
  group.members.each do |mem|
    if mem.new_entry?
      members << "#{mem.uid}[????]"
    else
      members << "#{mem.uid}[#{mem.uidNumber}]"
    end
  end
  
  puts("#{group.id}(#{group.gid_number}): #{members.join(', ')}")
end

group.save
