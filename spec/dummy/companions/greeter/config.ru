# frozen_string_literal: true

run do |_env|
  [200, { "content-type" => "text/plain" }, ["Greetings!"]]
end
