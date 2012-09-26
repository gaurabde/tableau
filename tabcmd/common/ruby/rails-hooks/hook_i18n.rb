# add date_locale for date formatting
# same as locale, default_locale in I18n
module I18n
  class << self
    def date_locale
      config.date_locale
    end

    def date_locale=(value)
      config.date_locale = (value)
    end

    def default_date_locale
      config.default_date_locale
    end

    def default_date_locale=(value)
      config.default_date_locale = (value)
    end

    def config
       # BUGZID:49635
       # This is a band aid fix for the i18n_config variable when it gets corrupted
       i18n_config = Thread.current[:i18n_config]
       i18n_config =  I18n::Config.new if i18n_config.nil? || !i18n_config.kind_of?(I18n::Config)
       Thread.current[:i18n_config] = i18n_config
    end

  end

  class Config
    # configuration value that is not global and scoped to thread
    def date_locale
      @date_locale ||= default_date_locale
    end

    # Sets the current date locale pseudo-globally, i.e. in the Thread.current hash.
    def date_locale=(locale)
      @date_locale = locale.to_sym rescue nil
    end

    def default_date_locale
      @@default_date_locale ||= :en_US
    end

    def default_date_locale=(locale)
      @@default_date_locale = locale.to_sym rescue nil
    end
  end
end
