# for this example the folder structure should be as follow
# 
# --+ mailer
#   |-- image.jpg
#   |-- mailer.rb (this file)
#   |--+ notifier
#      |-- email.rhtml

require 'rubygems'
require 'action_mailer'
class Notifier < ActionMailer::Base
  def mail(recipient, step, issue)
    # CONTINUITY_CONFIG = YAML.load_file("#{RAILS_ROOT}/config/continuity.yml")
    
    @recipients = CONTINUITY_CONFIG['overseers']
    if recipient != ""
      if @recipients == nil
        @recipients = recipient
      else
        @recipients.push(recipient)
      end
    end
    @subject = "Project broken at the #{step} step"
    if step == "success"
      @subject = "Build was successful"
    end
    @step = step
    @issue = issue
    @from = CONTINUITY_CONFIG['mail_from']
  end

end

Notifier.template_root = File.dirname(__FILE__)
