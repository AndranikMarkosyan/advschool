module I18nTasks
  module Utils
    CORE_KEYS = [:date, :time, :number, :datetime, :support]

    def self.dump_js(translations, locales = I18n.available_locales)
      # include all locales (even if untranslated) to avoid js errors
      locales.each { |locale| translations[locale.to_s] ||= {} }

      <<-TRANSLATIONS.gsub(/^ {8}/, '')
        // this file was auto-generated by rake i18n:generate_js.
        // you probably shouldn't edit it directly
        define(['i18nObj', 'jquery'], function(I18n, $) {
          $.extend(true, I18n, {translations: #{translations.to_ordered.to_json}});
        });
      TRANSLATIONS
    end
  end
end
