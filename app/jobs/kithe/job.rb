module Kithe

  app_superclass = begin
    ApplicationJob
  rescue NameError
    ActiveJob::Base
  end

  # Just a superclass for all kithe jobs, to make it easier to do track them or put them all in a
  # certain queue or whatever. Will inherit from local app ApplicationJob if it exists.
  Job = Class.new(app_superclass)
end
