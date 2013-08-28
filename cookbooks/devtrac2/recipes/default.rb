#
# Cookbook Name:: devtrac2
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute

package "python-pip" { action :install }
package "git" { action :install }
package "apache2.2" { action :install }
package "libapache2-mod-wsgi" { action :install }