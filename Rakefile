task :default => [:server]

task :server do
  ruby run.rb
end

task :vacuum do
  sh "wget -O/dev/null -q http://localhost:8000/api/notification/vacuum"
  puts ""
end