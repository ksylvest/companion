# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Companion::VERSION" do
  it "is the gem version" do
    expect(Companion::VERSION).to eq("0.1.0")
  end
end
