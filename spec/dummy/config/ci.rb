# frozen_string_literal: true

# Run using bin/ci

CI.run do
  step "RSpec", "bin/rspec"
end
