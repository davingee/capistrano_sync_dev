require "capistrano_sync_dev/version"

module CapistranoSyncDev
  load File.expand_path("../capistrano_sync_dev/sync/db.rake", __FILE__)
  load File.expand_path("../capistrano_sync_dev/sync/s3.rake", __FILE__)
end
