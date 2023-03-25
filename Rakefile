# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new

  RuboCop::RakeTask.new("rubocop:md") do |task|
    task.options << %w[-c .rubocop-md.yml]
  end
rescue LoadError
  task(:rubocop) {}
  task("rubocop:md") {}
end

desc "Run Ruby Next nextify"
task :nextify do
  sh "bundle exec ruby-next nextify -V"
end

desc "Run specs without Rails"
task "spec:norails" do
  rspec_args = ARGV.join.split("--", 2).then { (_1.size == 2) ? _1.last : nil }
  sh <<~COMMAND
    NO_RAILS=1 \
    rspec
    #{rspec_args}
  COMMAND
end

task default: %w[rubocop rubocop:md spec spec:norails]
