actions :detach, :delete

state_attrs :volume_id,
            :force

attribute :volume_id,             :kind_of => String, :name_attribute => true
attribute :force,                 :kind_of => [TrueClass, FalseClass], :default => false
attribute :device,                :kind_of => String
attribute :instance_id,           :kind_of => String


def initialize(*args)
  super
  #@action = :create
end