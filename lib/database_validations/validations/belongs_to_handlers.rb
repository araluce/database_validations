module DatabaseValidations
  module BelongsToHandlers
    extend ActiveSupport::Concern

    included do
      alias_method :validate, :valid?
    end

    def valid?(context = nil)
      output = super(context)

      Helpers.each_belongs_to_presence_validator(self.class) do |validator|
        validates_with(ActiveRecord::Validations::PresenceValidator, validator.validates_presence_options)
      end

      errors.empty? && output
    end

    def save(opts = {})
      return false unless Helpers.check_foreign_key_missing(self)

      ActiveRecord::Base.connection.transaction(requires_new: true) { super }
    rescue ActiveRecord::InvalidForeignKey => e
      Helpers.handle_foreign_key_error!(self, e)
      false
    end

    def save!(opts = {})
      raise ActiveRecord::RecordInvalid, self unless Helpers.check_foreign_key_missing(self)

      ActiveRecord::Base.connection.transaction(requires_new: true) { super }
    rescue ActiveRecord::InvalidForeignKey => e
      Helpers.handle_foreign_key_error!(self, e)
      raise ActiveRecord::RecordInvalid, self
    end

    private

    def perform_validations(options = {})
      options[:validate] == false || valid_without_database_validations(options[:context])
    end
  end

  module ClassMethods
    def db_belongs_to(name, scope = nil, **options)
      include(DatabaseValidations::ValidWithoutDatabaseValidations)
      @database_validations_opts ||= DatabaseValidations::OptionsStorage.new(self)

      belongs_to(name, scope, options.merge(optional: true))

      foreign_key = reflections[name.to_s].foreign_key

      @database_validations_opts.push_belongs_to(foreign_key, name)

      include(DatabaseValidations::BelongsToHandlers)
    end
  end
end
