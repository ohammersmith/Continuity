require File.dirname(__FILE__) + "/../../config/continuity"
require 'capistrano'
require 'action_mailer'
require 'mailer'

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
    s = %x[cd #{$project_dir} && git fetch && git diff --quiet ...FETCH_HEAD] # --quiet implies --exit-code
    new_version = $?.exitstatus
    if !new_version
      puts "No changes since last pull"
      FileUtils.rm_f 'build.pid'
      exit 0
    end


  end
  
  desc "Pull and deploy new build"
  task :deploy => [:check, :environment] do
    s = %x[cd #{$project_dir} && git pull]
    exit_status = $?.exitstatus
    email_address = %x[git log HEAD..FETCH_HEAD|egrep -o [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+]
    step = "\"git pull\""
    if exit_status != 0
      Notifier.deliver_mail(email_address, step, s)
      FileUtils.rm_f 'build.pid'
      exit 1
    end
    
    email_address = %x[cd #{$project_dir} && git log -1..HEAD|egrep -o [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+]
    email_address = "mwright@futuresinc.com"
    
    
    step = "git submodule update"
    s = %x[cd #{$project_dir} && git submodule update --init]
    exit_status = $?.exitstatus
    if exit_status != 0
      Notifier.deliver_mail(email_address, step, s)
      FileUtils.rm_f 'build.pid'
      exit 1
    end
    
    step = "rake db:migrate:reset"
    s = %x[ cd #{$project_dir} && rake db:migrate:reset]
    exit_status = $?.exitstatus
    if exit_status != 0
      
      Notifier.deliver_mail(email_address, step, s)
      FileUtils.rm_f 'build.pid'
      exit 1
    end
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
    email = "mwright@futuresinc.com"
    step = "success"
    issue = "None!"
    Notifier.deliver_mail(email, step, issue)
    FileUtils.rm_f 'build.pid'
  end
  
  desc "Test e-mail"
  task :email_test => :environment do
    email = "mwright@futuresinc.com"
    step = "test"
    issue = "Test Works!"
    Notifier.deliver_mail(email, step, issue)
  end
  
  
  desc "Installs Continuity's cronjob"
  task :install do
    #Consider adding a config check dependency
    s = %x[echo '\n */5 * * * * cd  root #{File.dirname(__FILE__)+"/../../"} && rake build_local:clean_up' >> /etc/crontab]
    if s.match('.*Permission.*Denied.*')
      puts "Installation failed, check your permissions."
    else
      puts "Cronjob installed successfully"
    end
  end
end