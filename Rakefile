# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

desc "Release the gem: build, create GitHub release, push to RubyGems"
task :release do
  spec = Gem::Specification.load("vcardfull.gemspec")
  version = spec.version.to_s

  current_branch = `git branch --show-current`.strip
  abort "Must be on main branch (currently on #{current_branch})" unless current_branch == "main"

  uncommitted = `git status --porcelain`.strip
  abort "There are uncommitted changes:\n#{uncommitted}" unless uncommitted.empty?

  sh "git diff origin/main..HEAD --quiet" do |ok, _|
    abort "There are unpushed commits" unless ok
  end

  sh "gem build vcardfull.gemspec"
  sh "gh release create v#{version} --title 'v#{version}' --generate-notes"
  sh "gem push vcardfull-#{version}.gem"
  rm "vcardfull-#{version}.gem"
end
