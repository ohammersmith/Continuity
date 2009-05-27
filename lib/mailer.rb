# for this example the folder structure should be as follow
# 
# --+ mailer
#   |-- image.jpg
#   |-- mailer.rb (this file)
#   |--+ notifier
#      |-- email.rhtml

require 'rubygems'
require 'action_mailer'
require File.dirname(__FILE__) + "/../config/continuity"
class Notifier < ActionMailer::Base
  def mail(recipients, step, issue)
    @recipients = recipients
    @subject = "Project broken at the #{step} step"
    @step = step
    @issue = issue
    @from = "ci@futuresinc.com" #Change this to be more modular
  end

end

Notifier.template_root = File.dirname(__FILE__)
