class openstack_tasks::ceilometer::pre_aodh {

  class { '::ceilometer::alarm::evaluator':
    evaluation_interval => 60,
  }

  class { '::ceilometer::alarm::notifier': }

  include ceilometer_ha::alarm::evaluator
  include ceilometer::params

  case $::osfamily {
    'RedHat': {
      $alarm_package = $::ceilometer::params::alarm_package_name[0]
    }
    'Debian': {
      $alarm_package = $::ceilometer::params::alarm_package_name[1]
    }
  }

  Package[$::ceilometer::params::common_package_name] ->
    Class['ceilometer_ha::alarm::evaluator']
  Package[$alarm_package] ->
    Class['ceilometer_ha::alarm::evaluator']
  Package<| title == $::ceilometer::params::alarm_package or
    title == 'ceilometer-common'|> ~>
      Service<| title == 'ceilometer-alarm-evaluator'|>
}