source "https://rubygems.org"

gemspec

gem "pry-byebug"

local_gemfile = File.join(__dir__, "Gemfile.local")

if File.exist?(local_gemfile)
  eval(File.read(local_gemfile)) # rubocop:disable Security/Eval
else
  gem "rails", "~> 5.2"
end
