# Not a doc string
class neutron::fuel_extras::corosync (
  $manage_ovs = true,
  $manage_metadata = true,
  $manage_l3 = true,
  $manage_dhcp = true
  )
{
  $neutron_config = { keystone => {
    auth_url          => 'http://192.168.0.2:35357/v2.0',
    admin_tenant_name => 'services',
    admin_user        => 'neutron',
    admin_password    => 'ngpeJBvA',},
    }
  include ::neutron::params

  class {'neutron::agents::ovs': }
  class {'neutron::agents::metadata':
    auth_password => 'asdf',
    shared_secret => 'zBaC0anS'
  }
  class {'neutron::agents::dhcp': }
  class {'neutron::agents::l3': }

  class {'neutron':
    rabbit_password => 'e6apye6c',
  }
  $debug = false
  ###### END HARD CODES FOR POC #####

  Package['pacemaker'] ->
    File<| title == 'ocf-mirantis-path' |> ->
    File<| title == 'q-agent-cleanup.py'|>

  if !defined(Package['lsof']) {
    package { 'lsof': }
  }

  if $manage_ovs {
    neutron::fuel_extras::corosync::cs_service {'ovs':
      ocf_script          => 'neutron-agent-ovs',
      csr_multistate_hash => { 'type' => 'clone' },
      csr_ms_metadata     => { 'interleave' => 'true' },
      csr_mon_intr        => '20',
      csr_mon_timeout     => '10',
      csr_timeout         => '80',
      service_name        => "p_${::neutron::params::ovs_agent_service}",
    }

    if defined(Class['neutron::agents::ovs']) {
      Neutron::Agents::Ovs {
        enabled         => false,
        manage_service  => false,
        before          => Neutron::Fuel_extras::Corosync::Cs_service['ovs']
      }
    } else {
      Neutron::Agents::Ml2::Ovs {
        enabled         => false,
        manage_service  => false,
        before          => Neutron::Fuel_extras::Corosync::Cs_service['ovs']
      }
    }
  } #End manage_ovs

  if $manage_metadata {
    neutron::fuel_extras::corosync::cs_service {'neutron-metadata-agent':
      ocf_script          => 'neutron-agent-metadata',
      csr_multistate_hash => { 'type' => 'clone' },
      csr_ms_metadata     => { 'interleave' => 'true' },
      csr_mon_intr        => '60',
      csr_mon_timeout     => '10',
      csr_timeout         => '30',
      service_name        => "p_${::neutron::params::metadata_agent_service}",
    }

    Neutron::Agents::Metadata {
      enabled         => false,
      manage_service  => false,
      before          => Neutron::Fuel_extras::Corosync::Cs_service['neutron-metadata-agent']
    }

  } # End manage_metadata

  if $manage_dhcp {
    neutron::fuel_extras::corosync::cs_service {'dhcp':
      ocf_script      => 'neutron-agent-dhcp',
      csr_parameters  => {
        'os_auth_url' => $neutron_config['keystone']['auth_url'],
        'tenant'      => $neutron_config['keystone']['admin_tenant_name'],
        'username'    => $neutron_config['keystone']['admin_user'],
        'password'    => $neutron_config['keystone']['admin_password'],
      },
      csr_metadata    => { 'resource-stickiness' => '1' },
      csr_mon_intr    => '20',
      csr_mon_timeout => '10',
      csr_timeout     => '60',
      service_name    => "p_${::neutron::params::dhcp_agent_service}",
    }

    if $manage_ovs {
#      Neutron::Fuel_extras::Corosync::Cs_service['ovs'] ->
      neutron::fuel_extras::corosync::cs_with_service {'dhcp-and-ovs':
        first   => "p_${::neutron::params::ovs_agent_service}",
        second  => "p_${::neutron::params::dhcp_agent_service}",
        require => Neutron::Fuel_extras::Corosync::Cs_service['ovs'],
      }
    }

    if $manage_metadata {
#      Neutron::Fuel_extras::Corosync::Cs_service['neutron-metadata-agent'] ->
      neutron::fuel_extras::corosync::cs_with_service {'dhcp-and-metadata':
        first   => "clone_p_${::neutron::params::metadata_agent_service}",
        second  => "p_${::neutron::params::dhcp_agent_service}",
        require => Neutron::Fuel_extras::Corosync::Cs_service['neutron-metadata-agent']
      }
    }

    Neutron::Agents::Dhcp {
      enabled         => false,
      manage_service  => false,
      before          => Neutron::Fuel_extras::Corosync::Cs_service['dhcp']
    }
  } # End manage_dhcp

  if $manage_l3 {
    neutron::fuel_extras::corosync::cs_service {'l3':
      ocf_script      => 'neutron-agent-l3',
      csr_parameters  => {
        'debug'       => $debug,
        'syslog'      => $::use_syslog,
        'os_auth_url' => $neutron_config['keystone']['auth_url'],
        'tenant'      => $neutron_config['keystone']['admin_tenant_name'],
        'username'    => $neutron_config['keystone']['admin_user'],
        'password'    => $neutron_config['keystone']['admin_password'],
      },
      csr_metadata    => { 'resource-stickiness' => '1' },
      csr_mon_intr    => '20',
      csr_mon_timeout => '10',
      csr_timeout     => '60',
      service_name    => "p_${::neutron::params::l3_agent_service}",
    }

    if $manage_ovs {
#      Neutron::Fuel_extras::Corosync::Cs_service['ovs'] ->
      neutron::fuel_extras::corosync::cs_with_service {'l3-and-ovs':
        first   => "clone_p_${::neutron::params::ovs_agent_service}",
        second  => "p_${::neutron::params::l3_agent_service}",
        require => Neutron::Fuel_extras::Corosync::Cs_service['ovs'],
      }
    }

    if $manage_metadata {
#      Neutron::Fuel_extras::Corosync::Cs_service['neutron-metadata-agent'] ->
      neutron::fuel_extras::corosync::cs_with_service {'l3-and-metadata':
        first   => "clone_p_${::neutron::params::metadata_agent_service}",
        second  => "p_${::neutron::params::l3_agent_service}",
        require => Neutron::Fuel_extras::Corosync::Cs_service['neutron-metadata-agent']
      }
    }

    if $manage_dhcp {
#      Neutron::Fuel_extras::Corosync::Cs_service['dhcp'] ->
      cs_colocation { 'l3-keepaway-dhcp':
        ensure     => present,
        score      => '-100',
        primitives => [
          "p_${::neutron::params::dhcp_agent_service}",
          "p_${::neutron::params::l3_agent_service}"
        ],
        require => Neutron::Fuel_extras::Corosync::Cs_service['dhcp']
      }
    }

    Cs_resource["p_${::neutron::params::l3_agent_service}"] ->
      Neutron::Fuel_extras::Corosync::Cs_with_service[
        'l3-and-ovs', 'l3-and-metadata']

    Neutron::Agents::L3 {
      enabled         => false,
      manage_service  => false,
      before          => Neutron::Fuel_extras::Corosync::Cs_service['l3']
    }

  } # End manage_l3

}
