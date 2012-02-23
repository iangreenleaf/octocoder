# A mixin for models that wish to cache data, to be refreshed after a certain
# amount of time.
module Cacheable
  def stale?
    time_now = DateTime.now
    cache_expires_at = self.updated_at + 1

    if time_now >= cache_expires_at
      return true
    else
      return false
    end
  end

  def refresh
    delete_cache
    create_cache
  end
end
