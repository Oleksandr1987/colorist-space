class HaircutStep < ApplicationRecord
  belongs_to :service_note, inverse_of: :haircut_steps

  validates :zone, presence: true

  ZONES = [
    "lower_occipital",
    "upper_occipital",
    "temporal",
    "fringe",
    "crown",
    "all_over"
  ].freeze

  INSTRUMENTS = [
    "scissors",
    "clipper",
    "razor",
    "texturizer"
  ].freeze

  PARTINGS = [
    "vertical",
    "horizontal",
    "diagonal_forward",
    "diagonal_back"
  ].freeze

  ELEVATIONS = [
    "0",
    "45",
    "90",
    "180"
  ].freeze

  CUT_TYPES = [
    "classic",
    "slide_cut",
    "point_cut",
    "blunt"
  ].freeze
end
