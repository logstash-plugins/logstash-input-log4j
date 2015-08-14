@files=[]

task :default do
  system("rake -T")
end

require 'jar_installer'
desc "install jars"
task :install_jars do
  Jars::JarInstaller.vendor_jars
end

require "logstash/devutils/rake"
