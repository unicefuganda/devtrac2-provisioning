#!/usr/bin/env bash

curl -L https://get.rvm.io | bash
source /etc/profile.d/rvm.sh
rvm install 1.9.3
gem install chef ruby-shadow --no-ri --no-rdoc
