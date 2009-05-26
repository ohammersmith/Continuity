require File.dirname(__FILE__) + "/../../config/continuity"
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
      
    end
    
    pid = Process.pid
    system("echo #{pid} >> build.pid")
    
  end
  
  desc "Check to see if github has updated"
  task :check => :check_lock do
    system 'git fetch && git diff --quiet ...FETCH_HEAD' # --quiet implies --exit-code
    new_version = $?.exitstatus
    if !new_version
      puts "No changes since last pull"
      FileUtils.rm_f 'build.pid'
      exit 0
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