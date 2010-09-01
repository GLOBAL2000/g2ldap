# Variables needed globally
$valid_types = {
  "fest" => [12,12],
  "zivi" => [9,2],
  "praktikum" => [4,2],
  "sonstiges" => [2,2],
  "karenz" => [0,6],
  "ehemalig" => [0,4],
  "extern" => [6,6], #Leute die zwar im Büro sind aber nicht zu GLOBAL gehören
}
$valid_types.default = [0,0]

# Definitions

def map_user_hash( origin, mappings, user )
  output = Hash.new
  mappings.each do | key, val |
    output[val.intern] = origin[key] if origin[key]
  end
  
  # Very unRubyish. Make this a lot prettyer for release!
  if output[:given_name] || output[:sn]
    output[:given_name] = user.given_name unless output[:given_name]
    output[:sn] = user.sn unless output[:sn]
    ( output[:given_name] && output[:sn] ) ? delimiter = " " : delimiter = ""
    
    output[:cn] = output[:given_name].to_s + delimiter.to_s + output[:sn].to_s
  end

  User.find(:all, :attribute => 'uidNumber', :value => origin[:uid]).empty? || raise("UID #{origin[:uid]} already exists.") if origin[:uid]
  
  output[:car_license] = (Date.today >> output[:car_license]).to_s if output[:car_license]

  #puts "Mapping: #{output.inspect}"
  return output
end

def map_group_hash( origin, mappings, group )
  # map hash
  output = Hash.new
  mappings.each do | key, val |
    output[val.intern] = origin[key] if origin[key]
  end

  # check for double gid
  if origin[:gid]
    Group.find(:all, :attribute => 'gidNumber', :value => origin[:gid]).empty? || raise("GID #{origin[:gid]} already exists.")
  end

  return output
end

def parse_new_group_default( attr, mappings )
  if !attr[:gid_number]
    attr[:gid_number] = 9999
    Group.find(:all, :attribute => 'gidNumber').collect { |group| group.gid_Number>attr[:gid_number] ? attr[:gid_number]=group.gid_Number : false }
    attr[:gid_number]+=1
  end
end


def parse_new_user_default( attr, mappings )
  attr[:gid_number] = 100 unless attr[:gid_number]

  # Get highest existing uid + 1, start at 999 (+1)
  if !attr[:uid_number]
    attr[:uid_number] = 999
    User.find(:all, :attribute => 'uidNumber').collect { |user| user.uid_Number>attr[:uid_number] ? attr[:uid_number]=user.uid_Number : false }
    attr[:uid_number]+=1
  end

  attr[:mail] = "#{attr[:uid]}@global2000.at" unless attr[:mail]
  attr[:home_directory] = "/home/#{attr[:uid]}" unless attr[:home_directory]
  attr[:login_shell] = "/bin/bash" unless attr[:login_shell]
  attr[:car_license] = (Date.today >> $valid_types[attr[:employee_type]][0]).to_s unless attr[:car_license]
end

def mod_obj( obj, attributes )
  attributes.each do |key, val|
    obj[key] = val
  end
end

def save_members_for_group( group, attr )
#  group.members does not work with strings!!
  current_members = Array(group[:member_uid])

  if attr[:members_given]
    (attr[:members] - current_members).each { |m| group.members.push(User.find(m)) }
    (current_members - attr[:members]).each { |m| group.members.delete(User.find(m)) }
  elsif attr[:remove_members_given] || attr[:add_members_given]
    # users to really add to the group
    ( attr[:add_members] - current_members ).each { |m| group.members.push(User.find(m)) } if attr[:add_members_given]
    # users to really remove from the group
    (attr[:remove_members] & current_members).each { |m| group.members.delete(User.find(m)) } if attr[:remove_members_given]
  end
end

# Mit user.groups = Array werden einfach die Gruppen überschrieben. Ist man bereits in einer Gruppe wird man zuerst entfernt und dann wieder hinzugefügt.
# Böses Verhalten, weil man so zuerst auf ldapadmins hinausgeschmissen wird und dann keinen Zugriff mer hat!
def save_groups_for_user( user, attr)
  current_groups = Array.new
  user.groups.each { |group| current_groups.push group[:cn] }
  if attr[:groups_given]
    # groups to add the user to
    user.groups.concat( attr[:groups] - current_groups)
    # groups to remove the user from
    (current_groups - attr[:groups]).each { |g| user.groups.delete(Group.find(g)) }
  elsif attr[:remove_groups_given] || attr[:add_groups_given]
    # groups to really add the user to
    user.groups.concat( attr[:add_groups] - current_groups ) if attr[:add_groups_given]
    # groups to really remove the user from
    (attr[:remove_groups] & current_groups).each { |g| user.groups.delete(Group.find(g)) } if attr[:remove_groups_given]
  end
end

def get_user( username , must_exist=true)
  if must_exist
    User.exists?(username) || raise("User #{username} does not exist.")
    return User.find(username)
  else
    !User.exists?(username) || raise("User #{username} already exists.")
    return User.new(username)
  end
end

def get_group( groupname, must_exist=true)
  if must_exist
    Group.exists?(groupname) || raise("Group #{groupname} does not exist.")
    return Group.find( groupname )
  else
    !Group.exists?(groupname) || raise("Group #{groupname} already exists.")
    return Group.new( groupname )
  end
end

def gen_report_line ( user )
  return [user.uid, user.cn, user.description, user.employee_type, user.car_license ]
end

def check_user_validity (user )
  exp = Date.parse(user.car_license) 
  if exp <= Date.today>>2 and exp > Date.today then
    return true
  else
    return false
  end
end

def get_expired_users ()
  out = []
  User.find(:all).collect { |user| out.push(user.uid) if Date.parse(user.car_license) <= Date.today }
  return out
end

def extend_user_validity( user )
  unless user.employee_type.nil?
    type_str = "mit dem typ #{user.employee_type}"
  else
    type_str = "ohne typ"
  end
  print "Um wieviele Monate soll #{user.uid} #{type_str} verlängert werden? [#{$valid_types[user.employee_type][1]}] "
  input = gets.chomp 
  input = $valid_types[user.employee_type][1].to_s if input.empty?
  extend_user_validity_by( user, input )
end

def extend_user_validity_by( user, month )
  user.car_license = (Date.today>>month.to_i).to_s
  user.save
end
