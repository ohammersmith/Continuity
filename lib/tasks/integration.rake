require 'octopi'
namespace :build_local do
  desc "Check to see if another process is running"
  task :check_lock do
    #Check for pid file, if one does not exist, write to it
    if File.exists?('build.pid') 
      print "File exists, exiting\n"
      exit 0
    else
      pid = Process.pid
      system("echo #{pid} >> build.pid")
    end
      
  end
  
  desc "Check to see if github has updated"
  task :check => :check_lock do
    #Check to see if there's a new build
    
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