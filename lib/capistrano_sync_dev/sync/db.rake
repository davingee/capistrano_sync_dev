namespace :sync do
  
  def download_tables(args={})
    %x(mysql -u#{ fetch(:sync_to)[ 'username' ] } #{ to_password } -h #{ to_host } #{ fetch(:sync_to)[ 'database' ] } -e 'SHOW TABLES').split(/\n/)
  end

  desc 'sync db to some env'
  task :db do
    on roles(:db ) do
        binding.pry
        return
        raise 'Can not change Production DB' if fetch(:sync_to_env) == 'production'
        all                   = fetch(:sync_table) == 'all' ? '_all-tables' : nil
        table                 = fetch(:sync_table) ? "_table_#{fetch(:sync_table)}" : nil if all.nil?

        file                  = "#{ fetch(:sync_download_path)}/#{ fetch(:sync_from)[ 'database' ] }_to_#{ fetch(:sync_to)[ 'database' ] }#{ all }#{ table }_#{ fetch(:sync_date) }"

        ssh_user              = self.host.netssh_options[:user]
        ssh_hostname          = self.host.hostname
        from_password         = fetch(:sync_from)[ 'password' ].nil? ? "" : "--password=#{ fetch(:sync_from)['password'] }"
        from_host             = self.host.hostname == fetch(:sync_from)[ 'host' ] ? '127.0.0.1' : fetch(:sync_from)[ 'host' ]
        from_local_or_remote  = fetch(:sync_from_env) == 'development' ? 'system' : 'execute'
        to_local_or_remote    = fetch(:sync_to_env) == 'development' ? 'system' : 'execute'
        to_password           = fetch(:sync_to)[ 'password' ].nil? ? "" : "--password=#{ fetch(:sync_to)[ 'password' ] }"
        to_host               = fetch(:sync_to)[ 'host' ].nil? ? 'localhost' : fetch(:sync_to)['host']
        alterations           = !fetch(:sync_table).nil?

        if !test("[ -f #{ file }.sql]") || fetch(:sync_from_file)
          # table         = ENV['table'].nil? ? "" : ENV['table'] # get only a specific table
          ignore_tables = []
          fetch(:sync_ignor_tables).each{|i| ignore_tables << "--ignore-table=#{ fetch(:sync_from)[ 'database' ] }.#{ i }" } unless alterations
          if fetch(:sync_replace_tables)
            ignore_tables = [] unless all.nil?
            send(
              from_local_or_remote, 
                "mysqldump -u #{ fetch(:sync_from)[ 'username' ] } #{ from_password } -h #{ from_host } #{ fetch(:sync_from)[ 'database' ] } #{ table } #{ ignore_tables.join(" ") } --single-transaction | gzip -9 -c >  #{ file }.sql.gz "
              )
          else
            if table
              query = %x(mysql -u#{ fetch(:sync_to)[ 'username' ] } #{ to_password } -h #{ to_host } #{ fetch(:sync_to)[ 'database' ] } -e 'select max(id) from #{table}')
              @max_id = query.split("\n").last
              max_table_id = @max_id ? "--where='id>#{@max_id}'" : ''
              send(from_local_or_remote, "mysqldump -t --insert-ignore --skip-opt -u #{ fetch(:sync_from)[ 'username' ] } #{ from_password } -h #{ from_host } #{ fetch(:sync_from)[ 'database' ] } #{ table } #{ ignore_tables.join(" ") } --single-transaction #{max_table_id} | gzip -9 -c >  #{ file }.sql.gz ")
            else
              %x(mysql -u#{ fetch(:sync_to)[ 'username' ] } #{ to_password } -h #{ to_host } #{ fetch(:sync_to)[ 'database' ] } -e 'SHOW TABLES').split(/\n/)[1..-1].each do |table_name|
                next if fetch(:sync_ignor_tables).include?(table_name) && all.nil?
                query = %x(mysql -u#{ fetch(:sync_to)[ 'username' ] } #{ to_password } -h #{ to_host } #{ fetch(:sync_to)[ 'database' ] } -e 'select max(id) from #{table_name}')
                @max_id = query.split("\n").last
                max_table_id = @max_id ? "--where='id>#{@max_id}'" : ''
                send(from_local_or_remote, "mysqldump -t --insert-ignore --skip-opt -u #{ fetch(:sync_from)[ 'username' ] } #{ from_password } -h #{ from_host } #{ fetch(:sync_from)[ 'database' ] } #{ table_name }  --single-transaction #{max_table_id} | gzip -9 -c >>  #{ file }.sql.gz ")
                puts table_name
              end
            end
          end
        end

        send(
          to_local_or_remote, "rsync -avzh #{ ssh_user }@#{ ssh_hostname }:#{ file }.sql.gz #{ file }.sql.gz"
        ) if fetch(:sync_to_env) == 'development'

        send(to_local_or_remote, "gzip -d -f #{ file }.sql.gz")
        send(to_local_or_remote, "mysql -u#{ fetch(:sync_to)[ 'username' ] } #{ to_password } -h #{ to_host } #{ fetch(:sync_to)[ 'database' ] } < #{ file }.sql")
        execute("rm -rf #{ file }.sql") unless fetch(:sync_from_file)
      end

  end
end

namespace :load do
  task :defaults do
    set :sync_from_file,        ->{ ENV['from_file'] || false }
    set :sync_replace_tables,    ->{ ENV['replace_table'] || false }
    set :sync_db_yaml,          ->{ "#{ Dir.pwd }/config/database.yml" }
    set :sync_db_config,        ->{ YAML::load(File.open(fetch(:sync_db_yaml))) }
    set :sync_to_env,           ->{ ENV['to'] || "development" }
    set :sync_from_env,         ->{ ENV['from'] || "production" }
    set :sync_to,               ->{ fetch(:sync_db_config)[fetch(:sync_to_env)] }
    set :sync_from,             ->{ fetch(:sync_db_config)[fetch(:sync_from_env)] }
    set :sync_table,            ->{ ENV['table'] }
    set :sync_date,             ->{ Date.today.strftime('%Y-%m-%d') }
    set :sync_puts,             ->{ true }
    set :sync_download_path,    ->{ '/tmp' }
    set :sync_ignor_tables,     ->{ 
      [
        'delayed_jobs',
        'emails',
        'audits',
        'pixels',
        'impression_mappings',
        'conversion_mappings',
        'campaign_position_histories',
        'leads',
        'campaign_bid_histories',
        'revenue_certainty_histories',
        'revenue_certainty_data',
        'analyzed_keywords'
      ]
    }
  end
end
