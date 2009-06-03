require 'capistrano'
require 'action_mailer'
require 'mailer'
require 'handler'


namespace :continuity do
  desc "Check to see if another process is running"
  task :check_lock do

    #Check for pid file, if one does not exist, write to it
    if File.exists?('build.pid') 
      
      if Time.now - File.ctime('build.pid') > 7200
        puts "Process has been running for >2 hours. Killing process."
        kpid = File.open('build.pid').read
        system("kill -9 #{kpid}")
        FileUtils.rm_f 'build.pid'
      else
        puts "File exists, exiting"
        exit 0
      end
      
    end
    
    pid = Process.pid
    system("echo #{pid} >> build.pid")
    
  end
  
  desc "Check to see if github has updated"
  task :check => [:check_lock, :environment] do
    project_dir = CONTINUITY_CONFIG['project_dir']
    s = %x[cd #{project_dir} && git fetch && git diff --quiet ...FETCH_HEAD] # --quiet implies --exit-code
    new_version = $?.exitstatus
    if new_version == 0
      puts "No changes since last pull"
      FileUtils.rm_f 'build.pid'
      exit 0
    end


  end
  
  desc "Pull and deploy new build"
  task :deploy => [:check, :environment] do
    project_dir = CONTINUITY_CONFIG['project_dir']
    deploy = CONTINUITY_CONFIG['deploy_command']
    env = CONTINUITY_CONFIG['environment']
    handler = Handler.new
    
    #### git pull new commits ###
    email_address = "mwright@futuresinc.com"
    s = %x[cd #{project_dir} && #{deploy}]
    exit_status = $?.exitstatus
    email_address = %x[git log HEAD..FETCH_HEAD|egrep -o [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+]
    email_address = "mwright@futuresinc.com"
    step = "\"deploy\""
    puts "Deploy Status: " + $?.exitstatus.to_s
    sleep 5
    handler.handle_status(exit_status, step, s, email_address)    
    email_address = %x[cd #{project_dir} && git log -1..HEAD|egrep -o [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+]
    email_address = "mwright@futuresinc.com"
    
    ### git submodule update --init ###
    step = "\"git submodule update\""
    s = %x[cd #{project_dir} && git submodule update --init]
    exit_status = $?.exitstatus
    handler.handle_status(exit_status, step, s, email_address)
    
    ### rake db:migrate:reset ###
    step = "\"rake db:migrate:reset\""
    s = %x[ cd #{project_dir} && rake RAILS_ENV=#{env} db:migrate:reset]
    exit_status = $?.exitstatus
    handler.handle_status(exit_status, step, s, email_address)
    
    ### rake:spec ###
    step = "\"rake spec\""
    s = %x[ cd #{project_dir} && rake test spec]
    exit_status = $?.exitstatus
    handler.handle_status(exit_status, step, s, email_address)
    
    ### rake features:default ###
    step = "\"rake features:default\""
    s = %x[ cd #{project_dir} && rake features:default]
    exit_status = $?.exitstatus
    handler.handle_status(exit_status, step, s, email_address)
    
    ### rake features:selenium
  end
  
  desc "Cleans up after CI has been run (automatically run)"
  task :clean_up => :deploy do
    email = "mwright@futuresinc.com"
    step = "success"
    issue = "None!"
    Notifier.deliver_mail(email, step, issue)
    FileUtils.rm_f 'build.pid'
  end
  
  desc "Checks for new build, deploys and runs tests and e-mails upon failure"
  task :build_local => :clean_up do
    #Nothing yet
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
    s = %x[echo '\n */5 * * * *   root cd #{File.dirname(__FILE__)+"/../../"} && rake continuity:build_local' >> /etc/crontab]
    if $?.exitstatus != 0
      puts "Installation failed, check your permissions."
    else
      puts "Cronjob installed successfully"
    end
  end
  
  
end