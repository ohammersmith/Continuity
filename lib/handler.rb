require 'mailer'
class Handler
  def handle_status(exit_code, step, fail, email_address)
    if exit_code != 0
      
      Notifier.deliver_mail(email_address, step, fail)
      FileUtils.rm_f 'build.pid'
      exit 1
    end
  end
end
