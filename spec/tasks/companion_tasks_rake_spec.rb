# frozen_string_literal: true

require "rails_helper"

RSpec.describe "lib/tasks/companion_tasks.rake" do
  it "loads" do
    path = File.expand_path("../../lib/tasks/companion_tasks.rake", __dir__)

    expect { load path }.not_to raise_error
  end
end
