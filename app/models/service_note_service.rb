class ServiceNoteService < ApplicationRecord
  belongs_to :service_note
  belongs_to :service
end
