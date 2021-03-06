# RUN: neut_vlan.ceph.ceil-primary-controller.overridden_ssl ubuntu
# RUN: neut_vlan.ceph.controller-ephemeral-ceph ubuntu
# RUN: neut_vlan.ironic.controller ubuntu
# RUN: neut_vlan_l3ha.ceph.ceil-controller ubuntu
# RUN: neut_vlan_l3ha.ceph.ceil-primary-controller ubuntu
# RUN: neut_vxlan_dvr.murano.sahara-controller ubuntu
# RUN: neut_vxlan_dvr.murano.sahara-primary-controller ubuntu
# RUN: neut_vxlan_dvr.murano.sahara-primary-controller.overridden_ssl ubuntu

require 'spec_helper'
require 'shared-examples'
manifest = 'database/database.pp'

describe manifest do

  before(:each) do
    Noop.puppet_function_load :is_pkg_installed
    MockFunction.new(:is_pkg_installed) do |function|
      allow(function).to receive(:call).and_return false
    end
  end

  shared_examples 'catalog' do
    let(:facts) {
      Noop.ubuntu_facts.merge({
        :mounts => ['/', '/boot', '/var/log', '/var/lib/glance', '/var/lib/mysql', '/var/lib/horizon'],
        :root_home => '/root'
      })
    }

    let(:network_scheme) do
      Noop.hiera_hash('network_scheme', {})
    end

    let(:endpoints) do
      network_scheme.fetch('endpoints', {})
    end

    let(:other_networks) do
      Noop.puppet_function 'direct_networks', endpoints, 'br-mgmt', 'netmask'
    end

    let(:access_networks) do
      access_networks = ['240.0.0.0/255.255.0.0'] + other_networks.split(' ')
    end

    let(:mysql_hash) do
      Noop.hiera 'mysql', {}
    end

    let(:database_nodes) do
      Noop.hiera('database_nodes')
    end

    let(:galera_node_address) do
      Noop.puppet_function 'get_network_role_property', 'mgmt/database', 'ipaddr'
    end

    let(:galera_nodes) do
      (Noop.puppet_function 'get_node_to_ipaddr_map_by_network_role', database_nodes, 'mgmt/database').values
    end

    let(:mysql_binary_logs) do
      Noop.hiera 'mysql_binary_logs', true
    end

    let(:log_bin) do
      Noop.puppet_function 'pick', mysql_hash['log_bin'], 'mysql-bin'
    end

    let(:expire_logs_days) do
      Noop.puppet_function 'pick', mysql_hash['expire_logs_days'], '1'
    end

    let(:max_binlog_size) do
      Noop.puppet_function 'pick', mysql_hash['max_binlog_size'], '64M'
    end

    let(:primary_controller) do
      Noop.hiera('primary_controller')
    end

    let(:mysql_database_password) do
      Noop.hiera_hash('mysql', {}).fetch('root_password', '')
    end

    let(:mysql_database_password_hash) do
      Noop.puppet_function 'mysql_password', mysql_database_password
    end

    let(:status_database_password) do
       Noop.hiera_hash('mysql', {}).fetch('wsrep_password', '')
    end

    let(:galera_node_address) do
      Noop.puppet_function 'get_network_role_property', 'mgmt/database', 'ipaddr'
    end

    let(:management_networks) do
      Noop.puppet_function 'get_routable_networks_for_network_role', network_scheme, 'mgmt/database', ' '
    end

    let(:custom_setup_class) do
      Noop.hiera('mysql_custom_setup_class', 'galera')
    end

    let(:mysql_socket) do
      case custom_setup_class
      when 'percona'
        '/var/lib/mysqld/mysqld.sock'
      when 'percona_packages'
        case facts[:osfamily]
        when 'Debian'
          '/var/run/mysqld/mysqld.sock'
        when 'RedHat'
          '/var/lib/mysql/mysql.sock'
        end
      else
        '/var/run/mysqld/mysqld.sock'
      end
    end

    it 'should contain galera' do
      should contain_class('galera').with(
        :vendor_type => 'MOS',
        :mysql_package_name => 'mysql-server-wsrep-5.6',
        :galera_package_name => 'galera-3',
        :client_package_name => 'mysql-client-5.6',
        :galera_servers => galera_nodes,
        :galera_master => false,
        :mysql_port => '3307',
        :root_password => mysql_database_password,
        :create_root_my_cnf => true,
        :create_root_user => primary_controller,
        :validate_connection => false,
        :status_check => false,
        :wsrep_group_comm_port => '4567',
        :bind_address => galera_node_address,
        :local_ip => galera_node_address,
        :wsrep_sst_method => 'xtrabackup-v2'
      )
      # TODO: check the dynamic override options
    end

    it 'should contain galera with undefined pid-file in override-options' do
      #OCF controls PID file thus it should be undefined
      override_options = Noop.resource_parameter_value self, 'class', 'galera', 'override_options'
      expect(override_options['mysqld']['pid-file']).to eq :undef
    end

    it 'should have explicit ordering galera status and LB status' do
      expect(graph).to ensure_transitive_dependency("Class[openstack::galera::status]", "Haproxy_backend_status[mysql]")
    end

    it 'should setup the /root/.my.cnf' do
      should contain_class('osnailyfacter::mysql_access').with(
        :db_password => mysql_database_password
      )
    end

    it 'should setup additional root grants from other hosts' do
      should contain_class('osnailyfacter::mysql_user_access').with(
        :db_user          => 'root',
        :db_password_hash => mysql_database_password_hash,
        :access_networks  => access_networks
      )
    end

    it 'should remove package provided wsrep.cnf' do
      should contain_file('/etc/mysql/conf.d/wsrep.cnf').with(
        :ensure => 'absent',
      ).that_comes_before('Class[mysql::server::installdb]')
    end

    it 'should configure galera check service' do
      should contain_class('openstack::galera::status').with(
        :status_user => 'clustercheck',
        :status_password => status_database_password,
        :status_allow => galera_node_address,
        :backend_host => galera_node_address,
        :backend_port => '3307',
        :backend_timeout => '10',
        :only_from => "127.0.0.1 240.0.0.2 #{management_networks}"
      )
    end

    it 'should configure pacemaker with mysql service' do
      should contain_class('cluster::mysql').with(
        :mysql_user => 'clustercheck',
        :mysql_password => status_database_password,
        :mysql_config => '/etc/mysql/my.cnf',
        :mysql_socket => mysql_socket,
      )
    end

    it "should configure Galera to use mgmt/database network for replication" do
      should contain_class('galera').with(
        'galera_servers' => galera_nodes,
      )
    end

    it "should configure mysql to ignore lost+found directory" do
      should contain_class('galera').with_override_options(
          /"ignore-db-dir"=>\["lost\+found"\]/
      )
    end

    if Noop.hiera('external_lb', false)
      database_vip = Noop.hiera('database_vip', Noop.hiera('management_vip'))
      url = "http://#{database_vip}:49000"
      provider = 'http'
    else
      url = 'http://' + Noop.hiera('service_endpoint').to_s + ':10000/;csv'
      provider = Puppet::Type.type(:haproxy_backend_status).defaultprovider.name
    end

    it 'should configure haproxy backend' do
      should contain_haproxy_backend_status('mysql').with(
        :url      => url,
        :provider => provider
      )
    end

    it 'should configure mysql binary logging by default' do
      expect(subject).to contain_class('galera').with_override_options(
          /"log_bin"=>"mysql-bin"/
      )
      expect(subject).to contain_class('galera').with_override_options(
          /"expire_logs_days"=>"#{expire_logs_days}"/
      )
      expect(subject).to contain_class('galera').with_override_options(
          /"max_binlog_size"=>"#{max_binlog_size}"/
      )
    end

    it 'should configure logging' do
      expect(subject).to contain_class('galera').with_override_options(
        Noop.hiera('use_syslog', true) ? /"syslog"=>true/ : /"log-error"=>"\/\S+"/
      )
    end
  end

  test_ubuntu_and_centos manifest
end

