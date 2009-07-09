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
    s = %x[cd #{project_dir} && git fetch && git diff --quiet ...FETCH_HEAD 2>&1] # --quiet implies --exit-code
    new_version = $?.exitstatus
    if new_version == 0 and !File.exists?('force')
      puts "No changes since last pull"
      FileUtils.rm_f 'build.pid'
      exit 0
    end
    #This is a hack put in place to fix the deploy bug until I figure out persistence
    if File.exists?('deploy_broken')
      puts "Deploy Broken!"
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
    s = %x[cd #{project_dir} && #{deploy} 2>&1]
    exit_status = $?.exitstatus
    email_address = %x[cd #{project_dir} && git fetch && git log  --pretty=format:%ae FETCH_HEAD~1..FETCH_HEAD 2>&1]
    step = "\"deploy\""
    if exit_status != 0
      system("echo '#{s}' >> deploy_broken")
    end
    handler.handle_status(exit_status, step, s, email_address)    
    #Breaks when the compiled version of grep does not support -m, and a git merge was performed due to the git@github.com:/user/repo line matching
    email_address = %x[cd #{project_dir} && git log --pretty=format:%ae -1..HEAD]
    
    ### git submodule update --init ###
    step = "\"git submodule update\""
    s = %x[cd #{project_dir} && git submodule update --init 2>&1]
    exit_status = $?.exitstatus
    handler.handle_status(exit_status, step, s, email_address)
    
    ### rake db:migrate:reset ###
    step = "\"rake db:skewer\""
    s = %x[ cd #{project_dir} && rake skewer 2>&1]
    exit_status = $?.exitstatus
    handler.handle_status(exit_status, step, s, email_address)
    
    ### rake:spec ###
    step = "\"rake test spec\""
    s = %x[ cd #{project_dir} && rake test spec 2>&1]
    exit_status = $?.exitstatus
    handler.handle_status(exit_status, step, s, email_address)
    
    ### rake features:default ###
    step = "\"rake features:default\""
    s = %x[ cd #{project_dir} && rake features:default 2>&1]
    exit_status = $?.exitstatus
    handler.handle_status(exit_status, step, s, email_address)
    
    ### rake features:selenium
    step = "\"rake features:selenium\""
    s = %x[ cd #{project_dir} && rake features:selenium 2>&1]
    exit_status = $?.exitstatus
    handler.handle_status(exit_status, step, s, email_address)
  end
  
  desc "Cleans up after CI has been run (automatically run)"
  task :clean_up => :deploy do
    email = ""
    step = "success"
    issue = "None!"
    Notifier.deliver_mail(email, step, issue)
    FileUtils.rm_f 'build.pid'
  end
  
  desc "Checks for new build, deploys and runs tests and e-mails upon failure"
  task :build_local => :clean_up do
    #Nothing yet
  end
  
  
  desc "Test e-mail functionality based on continuity.yml config"
  task :email_test => :environment do
    email = ""
    step = "test"
    issue = "Test Works!"
    Notifier.deliver_mail(email, step, issue)
  end
  
  
  desc "Installs Continuity's cronjob as rails user"
  task :install => :environment do
    #Consider adding a config check dependency
    user = CONTINUITY_CONFIG['user']
    s = %x[echo '\n */5 * * * *   #{user} cd #{File.dirname(__FILE__)+"/../../"} && rake continuity:build_local' >> /etc/crontab]
    if $?.exitstatus != 0
      puts "Installation failed"
    else
      puts "Cronjob installed successfully"
    end
  end
  
  desc "Puts Continuity into test mode, allowing for continuous deployment whether there is a new push or not"
  task :test_prepare do
    system("touch force")
  end
  
end