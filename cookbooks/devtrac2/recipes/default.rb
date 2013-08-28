#
# Cookbook Name:: devtrac2
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute

packages = %w{python-pip git apache2.2 libapache2-mod-wsgi}

packages.each do |package_name|
	package package_name do
		action :install 
	end
end