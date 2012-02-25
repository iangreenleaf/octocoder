# A mixin for models that wish to cache data, to be refreshed after a certain
# amount of time.
#
# Warning: I hope your model implements an EventMachine::Deferrable! Surprise!
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
      EventMachine.run do
        if model.nil?
          model = self.create attrs
          model.create_cache
        else
          model.refresh
        end
        model.callback do |m|
          EventMachine.stop
          return m
        end
      end
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
end
