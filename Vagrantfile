Vagrant.configure("2") do |config|
  config.vm.box_check_update = false
  config.vm.box = "ubuntu/trusty64"
  config.vm.provision "shell", inline: <<-SHELL
    apt-get remove -y chef puppet nfs-common
    apt-get autoremove -y
  SHELL
end
