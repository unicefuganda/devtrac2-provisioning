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

packages = %w{python-pip apache2.2 libapache2-mod-wsgi build-essential python-dev mongodb-10gen libfontconfig libgeos-dev}

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


envvars_content = <<-eos

unset HOME

# for supporting multiple apache2 instances
if [ "${APACHE_CONFDIR##/etc/apache2-}" != "${APACHE_CONFDIR}" ] ; then
        SUFFIX="-${APACHE_CONFDIR##/etc/apache2-}"
else
        SUFFIX=
fi

# Since there is no sane way to get the parsed apache2 config in scripts, some
# settings are defined via environment variables and then used in apache2ctl,
# /etc/init.d/apache2, /etc/logrotate.d/apache2, etc.
export APACHE_RUN_USER=www-data
export APACHE_RUN_GROUP=www-data
export APACHE_PID_FILE=/var/run/apache2$SUFFIX.pid
export APACHE_RUN_DIR=/var/run/apache2$SUFFIX
export APACHE_LOCK_DIR=/var/lock/apache2$SUFFIX
# Only /var/log/apache2 is handled by /etc/logrotate.d/apache2.
export APACHE_LOG_DIR=/var/log/apache2$SUFFIX

## The locale used by some modules like mod_dav
export LANG=C
## Uncomment the following line to use the system default locale instead:
#. /etc/default/locale

export LANG

## The command to get the status for 'apache2ctl status'.
## Some packages providing 'www-browser' need '--dump' instead of '-dump'.
#export APACHE_LYNX='www-browser -dump'

## If you need a higher file descriptor limit, uncomment and adjust the
## following line (default is 8192):
#APACHE_ULIMIT_MAX_FILES='ulimit -n 65536'
export DEVTRAC_ENV=Production

eos

file "/etc/apache2/httpd.conf" do 
	action :delete
end

file "/etc/apache2/envvars" do 
  action :delete
end

file "/etc/apache2/httpd.conf" do 
	content conf_content.gsub(/<SERVER_NAME>/,  node['SERVER_NAME'])
	action :create
end

file "/etc/apache2/envvars" do 
  content envvars_content
  action :create
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

execute "enable expires" do
  command "/usr/sbin/a2enmod expires"
end

execute "enable compress" do
  command "/usr/sbin/a2enmod deflate"
end

bash "stop apache" do
  code "apache2ctl stop"
end

sleep 2

bash "start apache" do
  code "apache2ctl start"
end

service "mongodb" do
  action [:enable, :start]
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
