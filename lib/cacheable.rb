# A mixin for models that wish to cache data, to be refreshed after a certain
# amount of time.
#
# Warning: I hope your model implements an EventMachine::Deferrable! Surprise!
module Cacheable
  def stale?
    time_now = DateTime.now
    cache_expires_at = self.updated_at + 1
    return time_now >= cache_expires_at
  end

  def refresh
    if stale?
      delete_cache
      create_cache
    else
      succeed self
    end
  end

  module ClassMethods
    def prime attrs
      model = self.first attrs
      if model.nil?
        model = self.create attrs
        model.create_cache
      else
        model.refresh
      end
      model
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
end
