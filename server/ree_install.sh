#!/bin/bash

# Install ree on the ec2onrails image
# This script gets uploaded and executed by
#
# cap trazzler:server:install:ree
#

# Hopefully the following gets taken care of w/a clean
# install of ree...
#
# TODO:  Not sure why these weren't added:
#
# /etc/hosts
#
# 127.0.0.1	db_primary
# 127.0.0.1	memcache
# 
#

# remove the old ruby (probably not necessary)
apt-get remove ruby ruby1.8 ruby1.8-dev libruby libruby1.8

cd /tmp
wget http://rubyforge.org/frs/download.php/68720/ruby-enterprise_1.8.7-2010.01_amd64.deb
dpkg -i ./ruby-enterprise_1.8.7-2010.01_amd64.deb
ln -s /usr/local/bin/ruby /usr/bin/ruby

# remove the RUBYLIB environment variable
echo 'PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/ec2onrails/bin"' > /etc/environment

# pre-req gems
gem install optiflag
gem install mysql
gem install mongrel
gem install mongrel_rails
gem install mongrel_cluster

# remove the old rake
rm -f /usr/bin/rake
gem install rake
ln -s /usr/local/bin/rake /usr/bin/rake
