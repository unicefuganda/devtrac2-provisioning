SERVER_NAME = "127.0.0.1"

bash "add mongo package repo " do
  code "sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10"
end

bash "add mongo source list" do
  code "echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list"
end

execute "apt-get-update" do
  command "apt-get update"
  action :run
end

packages = %w{python-pip apache2.2 libapache2-mod-wsgi build-essential python-dev mongodb-10gen}

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
	code "pip install -r requirements.txt"
end

service "mongodb" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
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
	action :create
end

bash "restart apache" do 
	code "apache2ctl restart"
end

ruby_block "check provisioning worked" do
	block do 
		if Net::HTTP.get(URI("http://127.0.0.1/")) =~ /DevTrac2/
			puts "\n\nProvisioning was successful"
		else
			puts "\n\nProvisioning failed"
		end
	end
end
