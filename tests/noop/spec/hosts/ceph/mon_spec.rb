# SKIP_HIERA: neut_vlan.ceph.ceil-primary-controller.overridden_ssl ubuntu FIXME
# SKIP_HIERA: neut_vlan.ceph.controller-ephemeral-ceph ubuntu FIXME
# RUN: neut_vlan.ironic.controller ubuntu
# SKIP_HIERA: neut_vlan_l3ha.ceph.ceil-controller ubuntu FIXME
# SKIP_HIERA: neut_vlan_l3ha.ceph.ceil-primary-controller ubuntu FIXME
# RUN: neut_vxlan_dvr.murano.sahara-controller ubuntu
# RUN: neut_vxlan_dvr.murano.sahara-primary-controller ubuntu
# RUN: neut_vxlan_dvr.murano.sahara-primary-controller.overridden_ssl ubuntu

require 'spec_helper'
require 'shared-examples'
manifest = 'ceph/mon.pp'

describe manifest do
  shared_examples 'catalog' do
    storage_hash = Noop.hiera_hash 'storage'
    ceph_monitor_nodes = Noop.hiera 'ceph_monitor_nodes'

    if (storage_hash['volumes_ceph'] or
        storage_hash['images_ceph'] or
        storage_hash['objects_ceph'] or
        storage_hash['ephemeral_ceph']
       )
      it { should contain_class('ceph').with(
           'mon_hosts'                => ceph_monitor_nodes.keys,
           'osd_pool_default_size'    => storage_hash['osd_pool_size'],
           'osd_pool_default_pg_num'  => storage_hash['pg_num'],
           'osd_pool_default_pgp_num' => storage_hash['pg_num'],
           'ephemeral_ceph'           => storage_hash['ephemeral_ceph'],
           )
         }
    else
      it { should_not contain_class('ceph') }
    end
  end

  test_ubuntu_and_centos manifest
end

