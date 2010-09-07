desc "Deploy."
task :deploy => %w(deploy:before deploy:push deploy:after)

desc "Set up deployment prerequisites."
task "deploy:newb" do
  %w(heroku taps).each do |this_gem|
    puts "sudo gem install #{this_gem}" unless Gem.available? this_gem
  end

  Deploy::ENVIRONMENTS.each do |branch, env|
    unless /^#{env}/ =~ `git remote`
      puts "git remote add #{env} git@heroku.com:myapp-#{env}.git"
      puts "git fetch #{env}"

      unless /#{branch}$/ =~ `git branch`
        puts "git branch #{branch} origin/#{env}"
      end
    end
  end
end

desc "Show undeployed changes."
task "deploy:pending" do
  env    = Deploy.env
  source = "origin/#{env}"
  target = "#{env}/master"
  cmd    = "git log #{target}..#{source} '--format=tformat:%s|||%aN|||%aE'"

  changes = `#{cmd}`.split("\n").map do |line|
    msg, author, email = line.split("|||").map { |e| e.empty? ? nil : e }
    msg << " [#{author || email}]" unless Deploy::PEOPLE.include? author
    msg
  end

  last = `git show --pretty=%cr #{target}`.split("\n").first
  puts "Last deploy to #{env} was #{last || 'never'}."

  unless changes.empty?
    puts
    changes.each { |change| puts "* #{change}" }
    puts
  end
end

# The push.

task("deploy:push") { sh "git push #{Deploy.env} #{Deploy.env}:master" }

# Hooks. Attach extra behavior with these.

task "deploy:before" => "deploy:pending"
task "deploy:after"

module Deploy

  # A map of local branches to deployment environments.

  ENVIRONMENTS = { "master" => "production", "next" => "next" }

  # The folks who are most likely to be committing. People who
  # aren't in this list get their names next to their commit
  # messages, so I can see what contractors are doing.

  PEOPLE = ["John Barnette"]

  # What's the current deployment environment?

  def self.env
    return @env if defined? @env

    unless /^\* (.*)$/ =~ `git branch`
      abort "I can't figure out which branch you're on."
    end

    branch = $1

    unless Deploy::ENVIRONMENTS.include? branch
      abort "I don't know how to deploy '#{branch}'."
    end

    @env = ENVIRONMENTS[branch]
  end
end
