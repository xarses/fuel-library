# class wrapper for fuel to use ceph module

class ceph::fuel () {
  #There should be no parameters to this class all settings should be discovered here
    ::Ceph {
      primary_mon       => filter_nodes($::fuel_settings['nodes'],
                              'role','ceph-primary-mon')[0]['name'],

      #Mon parameters
      mon_hosts         => nodes_with_roles($::fuel_settings['nodes'],
                             ['ceph-mon', 'primary-ceph-mon'],'name'),
      mon_ip_addresses  => nodes_with_roles($::fuel_settings['nodes'],
                             ['ceph-mon', 'primary-ceph-mon'], 'internal_address'),

      use_rgw                   => $::fuel_settings['storage']['objects_ceph'],
      glance_backend            => $glance_backend,
      rgw_use_keystone          => true,
      fsid                      => undef,
      osd_pool_default_pg_num   => $::fuel_settings['storage']['pg_num'],
      osd_pool_default_pgp_num  => $::fuel_settings['storage']['pg_num'],
      osd_pool_default_size     => $::fuel_settings['storage']['osd_pool_size'],
      cluster_network           => $::fuel_settings['storage_network_range'],
      public_network            => $::fuel_settings['management_network_range'],
      rgw_keystone_admin_token  => $::fuel_settings['keystone']['admin_token'],

      #RBD secret uuid, used in Nova/Cinder
      rbd_secret_uuid           => 'a5d0dd94-57c4-ae55-ffe0-7e3732a24455',

      #Rados Users and pools
      cinder_user   => 'volumes',
      cinder_pool   => 'volumes',
      glance_user   => 'images',
      glance_pool   => 'images',
      compute_user  => 'compute',
      compute_pool  => 'compute',
    }
  } ->

  case $::fuel_settings['role'] {
    'ceph-primary-mon', 'ceph-mon': {
      include ceph::mon

      # DO NOT SPLIT ceph auth command lines! See http://tracker.ceph.com/issues/3279
      ceph::pool {$glance_pool:
        user          => $glance_user,
        acl           => "mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=${glance_pool}'",
        keyring_owner => 'glance',
      }

      ceph::pool {$cinder_pool:
        user          => $cinder_user,
        acl           => "mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=${cinder_pool}, allow rx pool=${glance_pool}'",
        keyring_owner => 'cinder',
      }

      Class['ceph::conf'] -> Class['ceph::mon'] ->
      Ceph::Pool[$glance_pool] -> Ceph::Pool[$cinder_pool] ~>
      Service['ceph']
    }

    'ceph-radosgw': {
      if ($::ceph::use_rgw) {
        if ($::ceph::rgw_use_keystone) {
          Ceph::Radosgw {
            rgw_keystone_url => "http://${::fuel_settings['management_vip']}:5000"
          }

          Ceph::Keystone {
            pub_ip    => $::fuel_settings['public_vip'],
            adm_ip    => $::fuel_settings['management_vip'],
            int_ip    => $::fuel_settings['management_vip'],
            rgw_port  => 6780,
          }
        }

        include ceph::radosgw
        Class['ceph::radosgw'] ~>
        Service['ceph']

        Class['::keystone'] -> Class['ceph::radosgw']
      }

    }

    'ceph-osd': {
      if ! empty($osd_devices) {
        include ceph::osd
        Class['ceph::conf'] -> Class['ceph::osd'] ~> Service['ceph']
      }
    }

    'controller': {
      # FIXME(Awoodward): Need to implment
    }
    'compute': {
      ceph::pool {$compute_pool:
        user          => $compute_user,
        acl           => "mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=${cinder_pool}, allow rx pool=${glance_pool}, allow rwx pool=${compute_pool}'",
        keyring_owner => 'nova',
      }

      include ceph::openstack::nova_compute

      if ($::fuel_settings['storage']['ephemeral_ceph']) {
        include ceph:openstack:ephemeral
        Class['ceph::conf'] -> Class['ceph::openstack::ephemeral'] ~>
        Service[$::ceph::params::service_nova_compute]
      }

      Class['ceph::conf'] ->
      Ceph::Pool[$compute_pool] ->
      Class['ceph::openstack::nova_compute'] ~>
      Service[$::ceph::params::service_nova_compute]
    }

    'ceph-mds': { include ceph::mds }

    default: {}
  }
}
