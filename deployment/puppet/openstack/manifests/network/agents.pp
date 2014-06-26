# Not a doc string

class openstack::network::neutron_agents (
  # Agents to enable here
  $ovs_enable = true,
  $ovs_ha = true,
  $metadata_enable = true,
  $metadata_ha = true,
  $l3_enable = true,
  $l3_ha = true,
  $dhcp_enable = true,
  $dhcp_ha = true,

  # imported from openstack::neutron_router
  $service_provider         = 'generic',
  $verbose                  = false,
  $debug                    = false,
  $neutron_config = {}.
) {

  #We don't need to worry about $ovs_enable here since we took care of it in
  # network.pp. However it is passed to corosync so we can have ha start for
  # it.

  if $metadata_enable {
    class {'::neutron::agents::metadata':
      verbose          => $verbose,
      debug            => $debug,
      service_provider => $service_provider,
      neutron_config   => $neutron_config,
      # Only metadata still uses keystone config
    }
  }

  if $dhcp_enable {
    class { '::neutron::agents::dhcp':
      neutron_config   => $neutron_config,
      verbose          => $verbose,
      debug            => $debug,
      service_provider => $service_provider,
    }
  }

  if $l3_enable {
    class { '::neutron::agents::l3':
      neutron_config   => $neutron_config,
      verbose          => $verbose,
      debug            => $debug,
      service_provider => $service_provider,
    }
  }

  class {'neutron::fuel_extras::corosync':
    ovs_ha      => $ovs_ha,
    metadata_ha => $metadata_ha,
    l3_ha       => $l3_ha,
    dhcp_ha     => $dhcp_ha
  }
}