#    This file is part of EC2 on Rails.
#    http://rubyforge.org/projects/ec2onrails/
#
#    Copyright 2007 Paul Dowman, http://pauldowman.com/
#
#    EC2 on Rails is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    EC2 on Rails is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


# This script is meant to be run by rakefile-wrapper, which is run by
# Eric Hammond's Ubuntu build script: http://alestic.com/
# See the README file for details

require "rake/clean"
require 'yaml'
require 'erb'
# require "#{File.dirname(__FILE__)}/../gem/lib/ec2onrails/version_helper"

# package notes:
# * gcc:            libraries needed to compile c/c++ files from source
# * libmysqlclient-dev : provide mysqlclient-dev libs, needed for DataObject gems
# * nano/vim/less:  simle file editors and viewer
# * git-core:       because we are all using git now, aren't we?
# * xfsprogs:       help with freezing and resizing of persistent volumes
#

@packages = %w(
  adduser
  bison
  ca-certificates
  cron
  curl
  flex
  gcc
  git-core
  irb
  less
  libmysqlclient-dev
  libmysql-ruby
  libpcre3-dev
  libssl-dev
  libxml2-dev
  libxslt1-dev
  libyaml-ruby
  libzlib-ruby
  logrotate
  make
  mailx
  memcached
  mysql-client
  mysql-server
  nano
  openssh-server
  postfix
  rdoc
  ri
  rsync
  ruby-full
  subversion
  sysstat
  unzip
  varnish
  vim
  wget
  xfsprogs
)

# NOTE: the amazon-ec2 gem is now at github, maintained by
#       grempe-amazon-ec2.  Will move back to regular amazon-ec2
#       gem if/when he cuts a new release with volume and snapshot
#       support included
@rubygems = [
  "grempe-amazon-ec2",
  "god",
  "RubyInline",
  "memcache-client",
  "optiflag",
  "passenger",
  "rails",
  "rails -v '~> 2.3.5'",
  "right_aws"
]

@build_root = "/mnt/build"
@fs_dir = "#{@build_root}/ubuntu"

# @version = Ec2onrails::VersionHelper.string
@version = 'ami-fd4aa494'

task :default => :configure

desc "Removes all build files"
task :clean_all do |t|
  puts "Unmounting proc and dev from #{@build_root}..."
  run "umount #{@build_root}/ubuntu/proc", true
  run "umount #{@build_root}/ubuntu/dev", true

  puts "Removing #{@build_root}..."
  rm_rf @build_root
end


desc "Use aptitude to install required packages inside the image's filesystem"
task :install_packages do |t|
 unless_completed(t) do
    ENV['DEBIAN_FRONTEND'] = 'noninteractive'
    ENV['LANG'] = ''
    run_sudo "apt-get autoremove -y"
    run_sudo "aptitude update"
    run_sudo "aptitude install -y #{@packages.join(' ')}"
    run_sudo "aptitude clean"
  end
end

desc "Install required ruby gems inside the image's filesystem"
task :install_gems => [:install_packages] do |t|
  puts "install_gems: begin"
  unless_completed(t) do
    puts "install_gems: unless_completed:  begin"
    version = "1.3.5"
    dir = "60718"

    filename = "rubygems-#{version}.tgz"
    url = "http://rubyforge.org/frs/download.php/#{dir}/#{filename}"
    run_sudo "sh -c 'cd /tmp && wget -q #{url} && tar zxf #{filename}'"
    run_sudo "sh -c 'cd /tmp/rubygems-#{version} && ruby setup.rb'"
    run_sudo "ln -sf /usr/bin/gem1.8 /usr/bin/gem"
    #NOTE: this will update to the most recent rubygems version even if we haven't updated the url here
    run_sudo "gem update --system --no-rdoc --no-ri"
    run_sudo "gem update --no-rdoc --no-ri"
    run_sudo "gem sources -a http://gems.github.com"
    run_sudo "gem install gemcutter --no-rdoc --no-ri"
    run_sudo "gem tumble" # set gemcutter as default gem server
    @rubygems.each do |g|
      run_sudo "gem install #{g} --no-rdoc --no-ri"
    end
    puts "install_gems: unless_completed:  end"
  end
  puts "install_gems: end"
end

desc "Install nginx from source"
task :install_nginx => [:install_packages, :install_gems] do |t|
  unless_completed(t) do

    # To work around a Passenger bug, we need to edit the Rakefile.
    # Unfortunately this is a bit brittle and will break when Passenger is updated
    # The bug: http://code.google.com/p/phusion-passenger/issues/detail?id=316
    # The solution is to add -mno-tls-direct-seg-refs to the compiler options:
    #   http://blog.pacharest.com/2009/08/a-bit-technical-nginx-passenger-4gb-seg-fixup/
    replace_line("#{@fs_dir}/usr/lib/ruby/gems/1.8/gems/passenger-2.2.5/Rakefile", %q(EXTRA_CXXFLAGS = "-Wall -mno-tls-direct-seg-refs #{OPTIMIZATION_FLAGS}"), 50)

    nginx_version = "nginx-0.7.60"
    nginx_tar = "#{nginx_version}.tar.gz"

    nginx_img = "http://sysoev.ru/nginx/#{nginx_tar}"
    fair_bal_img = "http://github.com/gnosek/nginx-upstream-fair/tarball/master"
    src_dir = "/tmp/src/nginx"
    # Make sure the dir is created but empty...lets start afresh
    run_sudo "mkdir -p -m 755 #{src_dir}/ &&  rm -rf #{src_dir}/*"
    run_sudo "sh -c 'cd #{src_dir} && wget -q #{nginx_img} && tar -xzf #{nginx_tar}'"
    run_sudo "sh -c 'cd #{src_dir}/#{nginx_version} && \
       ./configure \
         --sbin-path=/usr/sbin \
         --conf-path=/etc/nginx/nginx.conf \
         --pid-path=/var/run/nginx.pid \
         --error-log-path=/mnt/log/nginx/default_error.log \
         --with-http_ssl_module \
         --with-http_stub_status_module \
         --add-module=`/usr/bin/passenger-config --root`/ext/nginx && \
       make && \
       make install'"
  end
end

desc "Install Ubuntu packages, download and compile other software, and install gems"
task :install_software => [:install_gems, :install_packages,
                           :install_nginx]

desc "Configure the image"
task :configure => [:install_software] do |t|
  puts ":configure:  begin"
  unless_completed(t) do
    puts ":configure:  unless_completed:  begin"
    sh("cp -r files/* #{@fs_dir}")
    replace("#{@fs_dir}/etc/motd.tail", /!!VERSION!!/, "Version #{@version}")

    run_sudo "/usr/sbin/adduser --system --group --disabled-login --no-create-home nginx"
    run_sudo "/usr/sbin/adduser --gecos ',,,' --disabled-password app"
    run_sudo "/usr/sbin/addgroup rootequiv"

    run_sudo "cp /root/.gemrc /home/app" # so the app user also has access to gems.github.com
    run_sudo "chown app:app /home/app/.gemrc"

    run "echo '. /usr/local/ec2onrails/config' >> #{@fs_dir}/root/.bashrc"
    run "echo '. /usr/local/ec2onrails/config' >> #{@fs_dir}/home/app/.bashrc"

    %w(mysql auth.log daemon.log kern.log mail.err mail.info mail.log mail.warn syslog user.log).each do |f|
      rm_rf "#{@fs_dir}/var/log/#{f}"
      run_sudo "ln -sf /mnt/log/#{f} /var/log/#{f}"
    end

    # Create symlinks to run scripts on startup
    run_sudo "update-rc.d ec2-first-startup start 91 S ."
    run_sudo "update-rc.d ec2-every-startup start 92 S ."

    # Disable the services that will be managed by god, depending on the roles
    %w(nginx mysql memcached varnish varnishncsa).each do |service|
      run_sudo "update-rc.d -f #{service} remove"
      run_sudo "update-rc.d #{service} stop 20 2 3 4 5 ."
    end

    # God is started by upstart so that it will be restarted automatically if it dies,
    # see /etc/event.d/god

    # Create the mail aliases db
    run_sudo "postalias /etc/aliases"

    run_sudo "chmod 0440 /etc/sudoers"
    puts ":configure:  unless_completed:  end"
  end
  puts ":configure:  end"
end

desc "This task is for deploying the contents of /files to a running server image to test config file changes without rebuilding."
task :deploy_files do |t|
  raise "need 'key' and 'host' env vars defined" unless ENV['key'] && ENV['host']
  run "rsync -rlvzcCp --rsh='ssh -l root -i #{ENV['key']}' files/ #{ENV['host']}:/"
end

##################

# Execute a given block and touch a stampfile. The block won't be run if the stampfile exists.
def unless_completed(task, &proc)
  stampfile = "#{@build_root}/#{task.name}.completed"
  unless File.exists?(stampfile)
    yield
    touch stampfile
  end
end

def run_chroot(command, ignore_error = false)
  run "chroot '#{@fs_dir}' #{command}", ignore_error
end

def run_sudo(command, ignore_error)
  sudo = true
  run(command, ignore_error, sudo)
end

def run(command, ignore_error = false, sudo = false)
  command = "sudo #{command}" if sudo
  puts "*** #{command}"
  result = system command
  raise("error: #{$?}") unless result || ignore_error
end

def replace_line(file, newline, linenum)
  contents = File.open(file, 'r').readlines
  contents[linenum - 1] = newline
  File.open(file, 'w') do |f|
    contents.each {|line| f << line}
  end
end

def replace(file, pattern, text)
  contents = File.open(file, 'r').readlines
  contents.each do |line|
    line.gsub!(pattern, text)
  end
  File.open(file, 'w') do |f|
    contents.each {|line| f << line}
  end
end
