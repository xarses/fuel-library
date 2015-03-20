notice('MODULAR: ntp-client.pp')

$management_vip  = hiera('management_vrouter_vip')
$ntp_server_conf = inline_template("<% if File.exist?('/etc/ntp.server.conf') -%>true<% end -%>")

if ! $ntp_server_conf {
  class { 'ntp':
    servers        => [$management_vip],
    service_ensure => running,
    service_enable => true,
  }
}

