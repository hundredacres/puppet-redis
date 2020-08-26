require 'spec_helper'

describe 'redis::sentinel' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }
      let(:config_file_orig) do
        case facts[:osfamily]
        when 'Archlinux'
          '/etc/redis/redis-sentinel.conf.puppet'
        when 'Debian'
          '/etc/redis/redis-sentinel.conf.puppet'
        when 'Suse'
          '/etc/redis/redis-sentinel.conf.puppet'
        when 'FreeBSD'
          '/usr/local/etc/redis-sentinel.conf.puppet'
        when 'RedHat'
          '/etc/redis-sentinel.conf.puppet'
        end
      end

      let(:pidfile) do
        if facts[:operatingsystem] == 'Ubuntu'
          facts[:operatingsystemmajrelease] == '16.04' ? '/var/run/redis/redis-sentinel.pid' : '/var/run/sentinel/redis-sentinel.pid'
        elsif facts[:operatingsystem] == 'Debian'
          facts[:operatingsystemmajrelease] == '9' ? '/var/run/redis/redis-sentinel.pid' : '/run/sentinel/redis-sentinel.pid'
        else
          '/var/run/redis/redis-sentinel.pid'
        end
      end

      describe 'without parameters' do
        let(:expected_content_header) do
          <<CONFIG
port 26379
dir #{facts[:osfamily] == 'Debian' ? '/var/lib/redis' : '/tmp'}
daemonize #{facts[:osfamily] == 'RedHat' ? 'no' : 'yes'}
pidfile #{pidfile}
CONFIG
        end

        let(:expected_content_monitor) do
          <<CONFIG

sentinel monitor mymaster 127.0.0.1 6379 2
sentinel down-after-milliseconds mymaster 30000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 180000
CONFIG
        end

        let(:expected_content_footer) do
          <<CONFIG

loglevel notice
logfile #{facts[:osfamily] == 'Debian' ? '/var/log/redis/redis-sentinel.log' : '/var/log/redis/sentinel.log'}
CONFIG
        end

        it { is_expected.to create_class('redis::sentinel') }
        it { is_expected.to contain_concat__fragment('sentinel_conf_header').with_content(expected_content_header) }
        it { is_expected.to contain_concat__fragment('sentinel_conf_monitor_mymaster').with_content(expected_content_monitor) }
        it { is_expected.to contain_concat__fragment('sentinel_conf_footer').with_content(expected_content_footer) }

        it {
          is_expected.to contain_service('redis-sentinel').
            with_ensure('running').
            with_enable('true')
        }

        if facts[:os]['family'] == 'Debian'
          it { is_expected.to contain_package('redis-sentinel').with_ensure('present') }
        else
          it { is_expected.not_to contain_package('redis-sentinel') }
        end
      end

      describe 'with custom parameters' do
        let(:params) do
          {
            sentinel_monitor: {
              'mymaster' => {
                'redis_host'             => '127.0.0.1',
                'redis_port'             => 6379,
                'quorum'                 => 2,
                'parallel_sync'          => 1,
                'auth_pass'              => 'password',
                'down_after'             => 6000,
                'failover_timeout'       => 28_000,
                'notification_script'    => '/path/to/bar.sh',
                'client_reconfig_script' => '/path/to/foo.sh'
              }
            },
            sentinel_bind: '192.0.2.10',
            working_dir: '/tmp/redis',
            log_file: '/tmp/barn-sentinel.log'
          }
        end

        let(:expected_content_header) do
          <<CONFIG
bind 192.0.2.10
port 26379
dir /tmp/redis
daemonize #{facts[:osfamily] == 'RedHat' ? 'no' : 'yes'}
pidfile #{pidfile}
CONFIG
        end

        let(:expected_content_monitor) do
          <<CONFIG

sentinel monitor mymaster 127.0.0.1 6379 2
sentinel down-after-milliseconds mymaster 6000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 28000
sentinel auth-pass mymaster password
sentinel notification-script mymaster /path/to/bar.sh
sentinel client-reconfig-script mymaster /path/to/foo.sh
CONFIG
        end

        let(:expected_content_footer) do
          <<CONFIG

loglevel notice
logfile /tmp/barn-sentinel.log
CONFIG
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('redis::sentinel') }
        it { is_expected.to contain_concat__fragment('sentinel_conf_header').with_content(expected_content_header) }
        it { is_expected.to contain_concat__fragment('sentinel_conf_monitor_mymaster').with_content(expected_content_monitor) }
        it { is_expected.to contain_concat__fragment('sentinel_conf_footer').with_content(expected_content_footer) }
      end
    end
  end
end
