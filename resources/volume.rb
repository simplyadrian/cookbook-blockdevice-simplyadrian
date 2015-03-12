actions :attach, :detach, :delete, :wait

state_attrs :access_key_id,
            :secret_access_key,
            :volume_id,
            :force,
            :device,
            :instance_id,
            :retention_check,
            :wait_for,
            :timeout

attribute :access_key_id,         :kind_of => String
attribute :secret_access_key,     :kind_of => String
attribute :volume_id,             :kind_of => String, :name_attribute => true
attribute :force,                 :kind_of => [TrueClass, FalseClass], :default => false
attribute :device,                :kind_of => String
attribute :instance_id,           :kind_of => String
attribute :retention_check,       :kind_of => [TrueClass, FalseClass], :default => false
attribute :wait_for,              :kind_of => String
attribute :timeout,               :kind_of => Integer

def initialize(*args)
  super
  @action = :attach
end