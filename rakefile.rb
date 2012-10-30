require 'resque/tasks'

namespace 'resque' do
  task 'setup' do
    require 'resque'
    require_relative 'lib/citation-depositor/resque'
    Resque.redis = 'localhost:6379'
  end
end
