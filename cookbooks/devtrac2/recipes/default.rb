# need to phantomjs to this
ENV['DEVTRAC_ENV'] = "Production"

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

packages = %w{python-pip apache2.2 libapache2-mod-wsgi build-essential python-dev mongodb-10gen freetype-devel fontconfig-devel}

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
    SetEnv DEVTRAC_ENV "Production"
    WSGIDaemonProcess devtrac2 threads=5 home=/var/www/devtrac2
    WSGIScriptAlias / /var/www/devtrac2/.wsgi

    SetEnv demo.templates /usr/local/wsgi/templates
    SetEnv SERVER_NAME <SERVER_NAME>
    
    Alias /static /var/www/devtrac2/static
    ExpiresDefault "access plus 1 hour"

    AddOutputFilterByType DEFLATE text/html text/plain text/xml application/javascript application/json text/css

    ErrorLog "/var/www/devtrac2/error.log"
    CustomLog "/var/www/devtrac2/access.log" combined

    <Directory /var/www/devtrac2>
        WSGIProcessGroup devtrac2
        WSGIApplicationGroup %{GLOBAL}
        Order deny,allow
        Allow from all
    </Directory>

    <Directory /var/www/devtrac2/static>
        Order deny,allow
        Allow from all
    </Directory>
</VirtualHost>
eos

file "/etc/apache2/httpd.conf" do 
	action :delete
end

directory "/var/www/devtrac2/logs" do
  action :create
  owner "www-data"
  group "www-data"
  mode '1777'
end

directory "/var/www/devtrac2/tmp/pdf" do
  action :create
  owner "www-data"
  group "www-data"
  mode '1777'
  recursive true
end

directory "/var/www/devtrac2/static/.webassets-cache" do
  action :create
  owner "www-data"
  group "www-data"
  mode '1777'
end

directory "/var/www/devtrac2/static/gen" do
  action :create
  owner "www-data"
  group "www-data"
  mode '1777'
end

file "/etc/apache2/httpd.conf" do 
	content conf_content.gsub(/<SERVER_NAME>/,  node['SERVER_NAME'])
	action :create
end

execute "enable expires" do
  command "/usr/sbin/a2enmod expires"
end

execute "enable compress" do
  command "/usr/sbin/a2enmod deflate"
end

ENV['DEVTRAC_ENV'] = "Production"

bash "restart apache" do
  code <<-EOH
    apache2ctl stop
    apache2ctl start
  EOH
end

bash "install phantomjs" do
  user "root"
  cwd "/var"
  code <<-EOH 
    cd /var
    curl -O https://phantomjs.googlecode.com/files/phantomjs-1.9.2-linux-x86_64.tar.bz2
    tar -xvf phantomjs-1.9.2-linux-x86_64.tar.bz2
    ln -s /var/phantomjs-1.9.2-linux-x86_64/bin/phantomjs /usr/bin/phantomjs
    rm phantomjs-1.9.2-linux-x86_64.tar.bz2
  EOH
end

ruby_block "check provisioning worked" do
	block do 
		if Net::HTTP.get(URI("http://127.0.0.1/")) =~ /DevTrac Global/
			puts "\n\nHome page works"
		else
			puts "\n\nProvisioning failed"
		end
	end
end

ruby_block "check can download pdf" do
  block do 

    url = URI.parse('http://127.0.0.1/devtrac_report/uganda')
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    if res.code == "200" && res['Content-Type'] == 'application/pdf'
      puts "\n\nDownload PDF works"
    else
      puts "\n\nProvisioning failed"
    end
   
  end
end
