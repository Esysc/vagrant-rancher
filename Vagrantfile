ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'
require 'yaml'

settings = YAML.load_file(File.expand_path('vagrant.yaml', __dir__))

Vagrant.configure("2") do |config|
  config.vm.box = settings['box_name']

  settings['vm'].each do |vm_config|
    config.vm.define vm_config['name'] do |vm|
      vm.vm.hostname = vm_config['name']
      vm.vm.network "private_network", ip: vm_config['ip']

      vm.vm.provider "virtualbox" do |vb|
        vb.memory = vm_config['memory']
        vb.cpus = vm_config['cpus']
        # Disable IPv6 on VirtualBox VMs
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      end

      # Disable IPv6 at the OS level
      vm.vm.provision "shell", inline: <<-SHELL
        echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
        sysctl -p
      SHELL

      # Install Docker + prerequisites
      vm.vm.provision "shell", path: "scripts/provision.sh"
    end
  end
end
