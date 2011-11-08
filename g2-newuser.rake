#!/usr/bin/rake -f

require 'rubygems'
require 'highline/import'

@userdata = Hash.new

check_if_user_exists = Proc.new { |usr|
  `g2ldap-user.rb ls --name #{usr} 2> /dev/null`
  ($?.exitstatus == 0) ? false : true
}

def get_user_id
  id = `g2ldap-user.rb ls --name #{@userdata[:name]} | grep uidNumber`
  return id[/(\d{5})/]
end

if ENV['dryrun']
  alias sh puts
end

def needenv(env)
  ENV[env.downcase] or ENV[env.upcase] or raise "Need parameter #{env}; start with #{env}=blubb"
end

@quota = "10485760"
case @quota[-1..-1]
when "M"
  @quota.chop!
  @quota = 1024 * @quota.to_i
when "G"
  @quota.chop!
  @quota = 1024 * 1024 * @quota.to_i
end

@afs_prefix = "/afs/global2000.at/home"

desc "Read minimal info"
task :read_minimal do
  @userdata[:name] = ENV['name'] || ask("Benutzername:  ") do |q| 
    q.responses[:not_valid] = "Username existiert bereits."
    q.case = :down
    q.validate = check_if_user_exists unless ENV['dryrun']
  end
  @userdata[:type] = ENV['type'] || ask("Typ (sonstiges, ehemalig, fest, karenz, extern, praktikum, zivi): ") { |q| q.validate = /\A(sonstiges|ehemalig|fest|karenz|extern|praktikum|zivi)\z/ }
end

desc "Read info needed for mail"
task :read_mail => [:read_minimal] do
  @userdata[:givenname] = ENV['givenname'] || ask("Vorname:  ") { |q| q.validate = /\A([a-zA-Z]|ö|ä|ü|Ö|Ä|Ü)*\z/ }
  @userdata[:surname] = ENV['surname'] || ask("Nachname:  ") { |q| q.validate = /\A([a-zA-Z]|-|ö|ä|ü|Ö|Ä|Ü)*\z/ }
  # @userdata[:full_mail] = (@userdata[:givenname] + "." + @userdata[:surname]).downcase.sub("ö","oe").sub("ä","ae").sub("ü","ue") + "@global2000.at"
end

desc "Read info needed for LDAP"
task :read_ldap => [:read_minimal, :read_mail] do
  @userdata[:groups] = ENV['groups'] || ask("Gruppen: ")
  @userdata[:desc] = ENV['desc'] || ask("Beschreibung: ")
end

desc "Create afs user"
task :afsuser => [:read_minimal, :check_ldap] do
  @userdata[:userid] = get_user_id
  sh "pts createuser -name #{@userdata[:name]} -id #{@userdata[:userid]}"
  case @userdata[:type]
  when "fest", "zivi"
    sh "pts adduser #{@userdata[:name]} fest"
  when "praktikum"
    @userdata[:prak_team] = ENV['prak_team'] || ask("Praktikum für welches Team (fr, oea, oh, pmi, proj, tikam): ") { |q| q.validate = /\A(fr|oea|oh|pmi|proj|tikam)\z/ }
    sh "pts adduser -user #{@userdata[:name]} -group praktika-#{@userdata[:prak_team]}"
  else
    puts "AFS Rechte bitte händisch einrichten"
  end
end

desc "Create afs home"
task :afshome => [:read_minimal, :afsuser] do
  sh "vos create afs b home.#{@userdata[:userid]}"
  sh "fs mkm #{@afs_prefix}/#{@userdata[:name]} home.#{@userdata[:userid]}"
  sh "fs setacl #{@afs_prefix}/#{@userdata[:name]} #{@userdata[:name]} write"
  sh "fs setacl #{@afs_prefix}/#{@userdata[:name]} mrbackupuserhimself read"
  sh "fs setquota #{@afs_prefix}/#{@userdata[:name]} -max #{@quota}"
  sh "touch #{@afs_prefix}/#{@userdata[:name]}/.RESET_ALL"
  sh "chown -R #{@userdata[:name]}:users #{@afs_prefix}/#{@userdata[:name]}"
  sh "chmod go-rwx #{@afs_prefix}/#{@userdata[:name]}"
end

desc "Create Kerberos user"
task :kerberosuser => [:read_minimal] do
  adm = `id -nu`.chomp
  sh "kadmin -p #{adm} -q 'ank -policy user #{@userdata[:name]}'"
end

desc "Mailserver"
task :mailuser => [:read_mail] do
#  sh "ssh root@mail /root/bin/new_user"
end

desc "Check that user already exists in LDAP/System"
task :check_ldap => [:read_minimal] do
  !check_if_user_exists.call(@userdata[:name]) or raise "User zuerst im LDAP/System anlegen" unless ENV['dryrun']
end

desc "Create LDAP user"
task :ldapuser => [:read_ldap] do
  command = "/usr/local/bin/g2ldap-user.rb add --name '#{@userdata[:name]}' --givenname '#{@userdata[:givenname]}' --surname '#{@userdata[:surname]}' --type '#{@userdata[:type]}'"
  command += " --groups '#{@userdata[:groups]}'" unless @userdata[:groups].empty?
  command += " --description '#{@userdata[:desc]}'" unless @userdata[:desc].empty?
  sh command
end

desc "Create new user"
task :default => [:read_ldap, :recovery, :ldapuser, :afsuser, :afshome, :kerberosuser] do

end

desc "Create new user without afs"
task :noafs => [:read_ldap, :recovery, :ldapuser, :kerberosuser] do

end

desc "Provide fast recovery info"
task :recovery do
  command = "Recovery: name='#{@userdata[:name]}' givenname='#{@userdata[:givenname]}' surname='#{@userdata[:surname]}' type='#{@userdata[:type]}'"
  command += " groups='#{@userdata[:groups]}'" unless @userdata[:groups].empty?
  command += " desc='#{@userdata[:desc]}'" unless @userdata[:desc].empty?
  puts command
end
