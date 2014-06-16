#Not a docstring
define neutron::precreate_network (
    $netdata
    )
{

  neutron_network { "${name}":
    ensure          => present,
    router_external => $netdata['L2']['router_ext'],
    tenant_name     => $netdata['tenant'],
    segment_id      => $netdata['L2']['segment_id'].
    physnet         => $netdata['L2']['physnet'],
    shared          => $netdata['shared']
  }

  neutron_subnet { "${name}_subnet":
    ensure       => present,
    cidr         => $netdata['L3']['subnet'],
    network_name => $name,
    tenant_name  => $netdata['tenant'],
    gateway      => $netdata['L3']['gateway'],
    enable_dhcp  => $netdata['L3']['enable_dhcp'],
    nameservers  => $netdata['L3']['nameservers'],
    floating     => $netdata['L3']['floating'],
  }

  neutron_network { 'private':
    ensure          => present,
    tenant_name     => 'admin',
  }

  neutron_subnet { 'private_subnet':
    ensure       => present,
    cidr         => '10.0.0.0/24',
    network_name => 'private',
    tenant_name  => 'admin',
  }

  # Tenant-private router - assumes network namespace isolation
  neutron_router { 'demo_router':
    ensure               => present,
    tenant_name          => 'admin',
    gateway_network_name => 'public',
    require              => Neutron_subnet['public_subnet'],
  }

  neutron_router_interface { 'demo_router:private_subnet':
    ensure => present,
  }

}