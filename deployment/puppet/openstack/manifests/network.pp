g# Entry points for OpenStack networking services
# not a doc string

class openstack::network (
  $use_ha = false,
  $network_provider = 'nova',
  $network_config = {},
  $verbose,
  $debug,
  $use_syslog,
  $syslog_log_facility,
  $agents,
  $compute,

  #Nova settings
  $private_interface,
  $public_interface,
  $floating_range,
  $network_manager,
  $network_config,
  $create_networks,
  $num_networks,
  $network_size,
  $nameservers,

  #openstack::network::agents settings
  $ovs_enable = true,
  $ovs_ha = true,
  $ovs_us_ml2 = true,
  $metadata_enable = true,
  $metadata_ha = true,
  $l3_enable = true,
  $l3_ha = true,
  $dhcp_enable = true,
  $dhcp_ha = true

  )
{
  case $network_provider {
    'nova': {
      class { 'nova::network':
        private_interface => $private_interface,
        public_interface  => $public_interface,
        fixed_range       => $fixed_range,
        floating_range    => $floating_range,
        network_manager   => $network_manager,
        config_overrides  => $network_config,
        create_networks   => $create_networks,
        num_networks      => $num_networks,
        network_size      => $network_size,
        nameservers       => $nameservers,
        enabled           => true,
        install_service   => true,
      }
    } # End case nova
    'neutron': {
      class {'::neutron':
        verbose => $verbose,
        debug => $debug,
        use_syslog => $use_syslog,
        log_facility => $syslog_log_facility,
        base_mac =>
        mac_generation_retries =>
        dhcp_lease_duration =>
        dhcp_agents_per_network =>
        allow_overlapping_ips =>
        rabbit_user =>
        rabbit_host =>
        rabbit_port =>
        rabbit_hosts =>
        rabbit_password =>

      }
      if $::role =~ /controller|compute/ {
        class {'nova::network::neutron':
          neutron_admin_password    => $quantum_config['keystone']['admin_password'],
          neutron_admin_tenant_name => $quantum_config['keystone']['admin_tenant_name'],
          neutron_region_name       => $quantum_config['keystone']['auth_region'],
          neutron_admin_username    => $quantum_config['keystone']['admin_user'],
          neutron_admin_auth_url    => $quantum_config['keystone']['auth_url'],
          neutron_url               => $quantum_config['server']['api_url'],
        }
      }
      if ($agents or $::role == 'compute') {
        case $network_config['mechanism'] {
          'ovs': {
            # todo(xarses): computes don't need db connection data
            class { '::neutron::plugins::ovs':
              neutron_config      => $neutron_config,
              #bridge_mappings     => ["physnet1:br-ex","physnet2:br-prv"],
            }
            class { 'neutron::agents::ovs':
              neutron_config   => $quantum_config,
              # bridge_uplinks   => ["br-prv:${private_interface}"],
              # bridge_mappings  => ['physnet2:br-prv'],
              # enable_tunneling => $enable_tunneling,
              # local_ip         => $internal_address,
            }

          } # End case ovs
          'linuxbridge': {} # End case linuxbridge
        }
      }
      if $::role == 'controller' {
        class { '::neutron::server':
          neutron_config     => $quantum_config,
          primary_controller => $primary_controller
        }
      }
      if $agents {
        class {'openstack::network::agents':
          agents => $agents,
          network_config => $network_config
        }

      }
    } # End case neutron
  } # End Case
}

class openstack::network::neutron_agents (
  $ovs_enable = true,
  $ovs_ha = true,
  $ovs_us_ml2 = true,
  $metadata_enable = true,
  $metadata_ha = true,
  $l3_enable = true,
  $l3_ha = true,
  $dhcp_enable = true,
  $dhcp_ha = true
  ) {

  if $ovs_enable {

    if $ovs_us_ml2 {
      #TODO: Remove when no longer supporting legacy OVS plugin
       class { '::neutron::plugins::ovs':
        neutron_config      => $neutron_config,
        #bridge_mappings     => ["physnet1:br-ex","physnet2:br-prv"],
      }
    } else {
      class {'::neutron::plugins:ml2':
      }
    }
    class { '::neutron::agents::ovs':
      service_provider => $service_provider,
      neutron_config   => $neutron_config,
    }
  }

  if $metadata_enable {
    class {'::neutron::agents::metadata':
      verbose          => $verbose,
      debug            => $debug,
      service_provider => $service_provider,
      neutron_config   => $neutron_config,
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
    ovs_ha          => $ovs_ha,
    metadata_ha     => $metadata_ha,
    l3_ha           => $l3_ha,
    dhcp_ha         => $dhcp_ha,
    auth_url        => $auth_url,
    admin_password  => $admin_password
  }
}