ActiveLdap::Base.setup_connection(
                                  :try_sasl => true,
                                  :allow_anonymous => false,
                                  :host => 'ldap1',
                                  :base => 'dc=global2000,dc=at'
)

class Group < ActiveLdap::Base
  ldap_mapping :dn_attribute => "cn",
               :classes => ['posixGroup']
  has_many :members, :class_name => 'User', :wrap => 'memberUid'
  has_many :primary_members, :class_name => 'User',
           :foreign_key => 'gidNumber',
           :primary_key => 'gidNumber'
end


class User < ActiveLdap::Base
  ldap_mapping :dn_attribute => 'uid', :prefix => 'ou=people',
               :classes => ['inetOrgPerson', 'posixAccount']
  belongs_to :primary_group, :class_name => "Group",
             :foreign_key => "gidNumber", :primary_key => "gidNumber"
  belongs_to :groups, :many => 'memberUid'

#  An example of using the old "return_objects" API with the
#  new ActiveRecord-style API.
  alias groups_mapping groups
  def groups(return_objects=true)
    return groups_mapping if return_objects
    attr = 'cn'
    Group.search(:attribute => 'memberUid',
                 :value => id,
                 :attributes => [attr]).map {|dn, attrs| attrs[attr]}.flatten
  end
end

class Ou < ActiveLdap::Base
  ldap_mapping :dn_attribute => 'ou', :prefix => '',
               :classes => ['top', 'organizationalUnit']
end
