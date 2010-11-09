#!/usr/bin/rake -f

if ENV['dryrun']
  alias sh puts
end

def needenv(env)
  ENV[env.downcase] or ENV[env.upcase] or raise "Need parameter #{env}; start with #{env}=blubb"
end

task :init do
  @name = needenv 'name'
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

desc "Create afs user"
task :afsuser => [:init] do
  userid = `id -u #{@name}`
  sh "pts createuser -name #{@name} -id #{userid}"
  # GROUPS here!!
end

desc "Create afs home"
task :afshome => [:init, :afsuser] do
  sh "vos create afs b home.#{@name}"
  sh "fs mkm #{@afs_prefix}/#{@name} home.#{@name}"
  sh "fs setacl #{@afs_prefix}/#{@name} #{@name} write"
  sh "fs setacl #{@afs_prefix}/#{@name} mrbackupuserhimself read"
  sh "fs setquota #{@afs_prefix}/#{@name} -max #{@quota}"
  sh "touch #{@afs_prefix}/#{@name}/.RESET_ALL"
  sh "chown -R #{@name}:users #{@afs_prefix}/#{@name}"
  sh "chmod go-rwx #{@afs_prefix}/#{@name}"
end

desc "Create Kerberos user"
task :kerberos => [:init] do
  adm = `id -nu`.chomp
  sh "kadmin -p #{adm} -q 'ank -policy user #{@name}'"
end

desc "Mailserver"
task :mail => [:init] do
  sh "ssh root@mail /root/bin/new_user"
end

task :default => [:kerberos, :afshome, :afsuser] do

end
