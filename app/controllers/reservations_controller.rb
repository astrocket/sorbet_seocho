# typed: true
class ReservationsController < ApplicationController
  def index
    reservation = Reservation.first
    name = reservation&.name_i18n(:ko)

    render json: name
  end
end
