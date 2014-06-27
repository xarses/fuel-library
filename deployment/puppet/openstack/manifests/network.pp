# Entry points for OpenStack networking services
# not a doc string

class openstack::network (
  $neutron_db_uri,
  $network_provider = 'neutron',
  $agents           = ['ovs']
  $ha_agents        = false,

  $verbose    = false,
  $debug      = false,
  $use_syslog = flase,

  $syslog_log_facility = 'LOG_USER',

  # ML2 settings
  $type_drivers          = ['local', 'flat', 'vlan', 'gre', 'vxlan'],
  $tenant_network_types  = ['local', 'flat', 'vlan', 'gre', 'vxlan'],
  $mechanism_drivers     = ['openvswitch', 'linuxbridge'],
  $flat_networks         = ['*'],
  $network_vlan_ranges   = ['physnet1:1000:2999'],
  $tunnel_id_ranges      = ['20:100'],
  $vxlan_group           = '224.0.0.1',
  $vni_ranges            = ['10:100'],

  # amqp
  $rabbit_user ,
  $rabbit_host ,
  $rabbit_port ,
  $rabbit_hosts ,
  $rabbit_password ,

  # keystone
  $admin_password    = 'asdf123',
  $admin_tenant_name = 'services',
  $admin_username    = 'neutron',
  $auth_url          = 'http://127.0.0.1:5000/v2.0',
  $region            = 'RegionOne',
  $api_url           = $quantum_config['server']['api_url'],

  # Nova settings
  $private_interface,
  $public_interface,
  $floating_range,
  $network_manager,
  $network_config,
  $create_networks,
  $num_networks,
  $network_size,
  $nameservers,

  # Neutron
  $base_mac     = 'fa:16:3e:00:00:00',
  $core_plugin  = 'openvswitch'

  # Precreate networks and routers
  $precreate = {}
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
        #verbose                 => $verbose,
        debug                   => $debug,
        use_syslog              => $use_syslog,
        log_facility            => $syslog_log_facility,
        base_mac                => $base_mac,
        core_plugin             => $core_plugin,
        mac_generation_retries  => 32,
        dhcp_lease_duration     => 120,
        dhcp_agents_per_network => 1,
        report_interval         => 5,
        rabbit_user             => $rabbit_user,
        rabbit_host             => $rabbit_host,
        rabbit_port             => $rabbit_port,
        rabbit_hosts            => $rabbit_hosts,
        rabbit_password         => $rabbit_password

      }
      if $::role =~ /controller|compute/ {
        class {'nova::network::neutron':
          neutron_admin_password    => $admin_password,
          neutron_admin_tenant_name => $admin_tenant_name,
          neutron_region_name       => $region,
          neutron_admin_username    => $admin_username,
          neutron_admin_auth_url    => $auth_url,
          neutron_url               => $api_url,
        }
      }

      if $::role =~ /controller/ {
        class { '::neutron::server':
          auth_password => $admin_password,
          auth_tenant   => $admin_tenant_name,
          auth_username => $admin_username,
          auth_uri      => $auth_url,

          database_retry_interval => 2,
          database_connection     => $neutron_db_uri
          database_max_retries    => -1

          agent_down_time => 15
        }
      }
      if $agents {
        class {'openstack::network::neutron_agents':
          agents            => $agents,
          admin_password    => $admin_password,
          admin_tenant_name => $admin_tenant_name,
          admin_username    => $admin_username,
          auth_url          => $auth_url,
        }

      }
    } # End case neutron
  } # End Case
}
