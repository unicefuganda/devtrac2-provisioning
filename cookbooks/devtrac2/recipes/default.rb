#
# Cookbook Name:: devtrac2
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute

SERVER_NAME = "127.0.0.1"

packages = %w{python-pip apache2.2 libapache2-mod-wsgi}

packages.each do |package_name|
	package package_name do
		action :install 
	end
end

git "/var/www/devtrac2" do
	repository "https://github.com/unicefuganda/devtrac2.git"
	action :checkout
end

bash "install pip requirements" do 
	cwd "/var/www/devtrac2"
	code "pip install -r requirments.txt"
end

conf_content = <<-eos
<VirtualHost *>
    ServerName <SERVER_NAME>

    WSGIDaemonProcess devtrac2 threads=5
    WSGIScriptAlias / /var/www/devtrac2/.wsgi

    <Directory /var/www/devtrac2>
        WSGIProcessGroup devtrac2
        WSGIApplicationGroup %{GLOBAL}
        Order deny,allow
        Allow from all
    </Directory>
</VirtualHost>
eos

file "/etc/apache2/httpd.conf" do 
	action :delete
end

file "/etc/apache2/httpd.conf" do 
	content conf_content.gsub(/<SERVER_NAME>/, SERVER_NAME)
	action :create_if_missing
end

bash "restart apache" do 
	code "apache2ctl restart"
end