# Companion

Companion is a mountable Rails engine for running a companion application (e.g. Node, Python, Go, etc.) alongside a Rails application. Companion spawns and supervises the process, then proxies traffic from a mounted path in your Rails routes to the spawned process.

## Usage

### Installation

**Gemfile**

```ruby
gem "companion"
```

```bash
bundle install
```

### Configuration

Initialize your application via a an initializer (e.g. `config/initializers/companion.rb`):

```ruby
# config/initializers/companion.rb
Companion.configure do |config|
  config.app :dashboard do |app|
    app.command = -> { |port| "npm run serve -- --port {port}" }
    app.directory = Rails.root.join("dashboard")
    app.environment = { "NODE_ENV" => Rails.env.production? ? "production" : "development" }
  end
end
```

### Routing

Mount your application as an engine in `config/routes.rb`:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount Companion::Engine.app(:dashboard), at: "/dashboard"
end
```

## Examples

**companions/greeter/Gemfile**

```ruby
source "https://rubygems.org"

gemspec

gem "rack"
```

**companions/greeter/config.ru**

```ruby
# companions/greeter/config.ru

run do |env|
  [200, { "content-type" => "text/plain" }, ["Greetings!"]]
end
```

**config/initializers/companion.rb**

```ruby
Companion.configure do |config|
  config.app :greeter do |app|
    app.command = -> { |port| "rackup --port #{port}" }
    app.directory = Rails.root.join("companions", "greeter")
  end
end
```

**config/routes.rb**

```ruby
Rails.application.routes.draw do
  mount Companion::Engine.app(:greeter), at: "/greeter"
end
```

```bash
rails server
```

```bash
curl --verbose https://localhost:3000/greeter
```
