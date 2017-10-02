namespace :sync do
  
  desc 'sync s3 to some s3 env'
  task :s3 do
    raise 'Can not change Production S3' if fetch(:sync_s3_to_env) == 'production'
    delete    = fetch(:sync_s3_delete_old) == true ? '--delete ' : ''
    path      = fetch(:sync_s3_path) ? "#{fetch(:sync_s3_path).gsub(/(\A\/|\/\z)/, '')}/" : ''
    id        = fetch(:sync_s3_id) ? fetch(:sync_s3_id).gsub(/(\A\/|\/\z)/, '') : ''
    if fetch(:sync_s3_puts)
      puts "running aws s3 sync #{ delete } --acl=#{ fetch(:sync_s3_acl) } s3://#{ fetch(:sync_s3_from) }/#{path}#{id} s3://#{ fetch(:sync_s3_to) }/#{path}#{id}"
    end
    system("aws s3 sync #{ delete } --acl=#{ fetch(:sync_s3_acl) } s3://#{ fetch(:sync_s3_from) }/#{path}#{id} s3://#{ fetch(:sync_s3_to) }/#{path}#{id}")
  end
end

namespace :load do
  task :defaults do
    set :sync_s3_yaml,            ->{ "#{ Dir.pwd }/config/s3.yml" }
    set :sync_s3_to_env,          ->{ ENV['to'] || "development" }
    set :sync_s3_from_env,        ->{ ENV['from'] || "production" }
    set :sync_s3_config,          ->{ YAML::load(File.open(fetch(:sync_s3_yaml))) }
    set :sync_s3_credential_path, ->{ 'bucket' }
    set :sync_s3_to,              ->{ fetch(:sync_s3_config)[fetch(:sync_s3_to_env)][fetch(:sync_s3_credential_path)] }
    set :sync_s3_from,            ->{ fetch(:sync_s3_config)[fetch(:sync_s3_from_env)][fetch(:sync_s3_credential_path)] }
    set :sync_s3_path,            ->{ ENV['path'] }
    set :sync_s3_id,              ->{ ENV['id'] }
    set :sync_s3_delete_old,      ->{ true }
    set :sync_s3_acl,             ->{ 'public-read' }
    set :sync_s3_puts,            ->{ true }
  end
end
