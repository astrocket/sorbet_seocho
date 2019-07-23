# typed: true
class Reservation < ApplicationRecord

  belongs_to :booker

  def name_i18n(country_code)
    translate_api(booker.name, country_code)
  end

  private

  def translate_api(target, country_code)
    "이한결(#{target})" if country_code == :ko
  end
end
