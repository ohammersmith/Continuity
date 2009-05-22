require 'octopi'

include Octopi

namespace :build_local do
  desc "Check to see if another process is running"
  task :check_lock do
    #Check for pid file, if one does not exist, write to it
    if File.exists?('build.pid') 
      
      if Time.now - File.ctime('build.pid') > 7200
        puts "Process has been running for >2 hours. Killing process."
        kpid = File.open('build.pid').read
        system("kill -9 #{kpid}")
      else
        puts "File exists, exiting"
        exit 0
      end
      
    else
      pid = Process.pid
      system("echo #{pid} >> build.pid")
    end
    
  end
  
  desc "Check to see if github has updated"
  task :check => :check_lock do
    #Check to see if there's a new build
    Api.authenticated_with :config => "config/github.yml" do |g|
      user = User.find("mdwrigh2")
      puts "Username - #{user.login}"
      repos = user.repositories
      repos.each do |r|
        puts "Repository: #{r.tags}"
      end
      # repo = user.repository("continuity")
      # commit = repo.commits.first
      # puts "Commit: #{commit.id} - #{commit.message} - by #{commit.author['name']}"
    end
  end
  
  desc "Pull new build"
  task :deploy => :check do
    #Deploy new build to edge
  end
  
  desc "Run RSpec Tests"
  task :spec => :deploy do
    #Run RSpec tests
  end
  
  desc "Run Cucumber Tests"
  task :cucumber => :spec do
    #Run Cucumber tests
  end
  
  desc "Removes the PID file"
  task :clean_up => :cucumber do
    FileUtils.rm_f 'build.pid'
  end
end