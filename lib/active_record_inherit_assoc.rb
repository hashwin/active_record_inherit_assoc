require 'active_record'

if ActiveRecord::VERSION::MAJOR < 4
  ActiveRecord::Associations::Builder::HasMany.valid_options   << :inherit
  ActiveRecord::Associations::Builder::HasOne.valid_options    << :inherit
  ActiveRecord::Associations::Builder::BelongsTo.valid_options << :inherit
else
  ActiveRecord::Associations::Builder::Association.valid_options << :inherit
end

module ActiveRecordInheritAssocPrepend
  def target_scope
    if inherited_attributes = attribute_inheritance_hash
      super.where(inherited_attributes)
    else
      super
    end
  end

  private

  def attribute_inheritance_hash
    return nil unless reflection.options[:inherit]
    Array(reflection.options[:inherit]).inject({}) { |hash, obj| hash[obj] = owner.send(obj) ; hash }
  end
end

ActiveRecord::Associations::Association.send(:prepend, ActiveRecordInheritAssocPrepend)

module ActiveRecordInheritPreloadAssocPrepend
  def associated_records_by_owner(*args)
    super.tap do |result|
      next unless reflection.options[:inherit]
      result.each do |owner, associated_records|
        filter_associated_records_with_inherit!(owner, associated_records)
      end
    end
  end

  def filter_associated_records_with_inherit!(owner, associated_records)
    associated_records.select! do |record|
      Array(reflection.options[:inherit]).all? do |method_name|
        record.send(method_name) == owner.send(method_name)
      end
    end
  end
end

ActiveRecord::Associations::Preloader::Association.send(:prepend, ActiveRecordInheritPreloadAssocPrepend)

class ActiveRecord::Base
  # Makes the model inherit the specified attribute from a named association.
  #
  # parent_name - The Symbol name of the parent association.
  # options     - The Hash options to use:
  #               :attr - A Symbol or an Array of Symbol names of the attributes
  #                       that should be inherited from the parent association.
  #
  # Examples
  #
  #   class Post < ActiveRecord::Base
  #     belongs_to :category
  #     inherits_from :category, :attr => :account
  #   end
  #
  def self.inherits_from(parent_name, options = {})
    attrs = Array.wrap(options.fetch(:attr))

    before_validation do |model|
      parent = model.send(parent_name)

      attrs.each do |attr|
        model[attr] = parent[attr] if parent.present?
      end
    end
  end
end
