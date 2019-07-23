# typed: true
class ReservationsController < ApplicationController
  def index
    reservation = Reservation.first
    name = reservation&.booker_name_i18n(:ko)

    render json: name
  end
end
