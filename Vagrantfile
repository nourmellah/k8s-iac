Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false
  config.ssh.insert_key = false

  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true if vb.respond_to?(:linked_clone=)
  end

  nodes = [
    { name: "cp1",          ip: "192.168.56.10", memory: 3584, cpus: 2 },
    { name: "worker-app-1", ip: "192.168.56.11", memory: 1536, cpus: 2 },
    { name: "worker-app-2", ip: "192.168.56.12", memory: 2048, cpus: 2 },
    { name: "worker-ci",    ip: "192.168.56.13", memory: 3072, cpus: 2 }
  ]

  nodes.each do |node|
    config.vm.define node[:name] do |machine|
      machine.vm.hostname = node[:name]
      machine.vm.network "private_network", ip: node[:ip]

      machine.vm.provider "virtualbox" do |vb|
        vb.name = "iac-k8s-#{node[:name]}"
        vb.memory = node[:memory]
        vb.cpus = node[:cpus]
      end

      machine.vm.provision "shell", inline: <<-SHELL
        set -eux
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
          python3 python3-apt curl ca-certificates gnupg lsb-release
      SHELL
    end
  end
end
