# -*- mode: ruby -*-
# vi: set ft=ruby :

$msg = <<MSG
--------------------------------------------------------------------
This box uses Virtualbox > 6.0 standards for graphic controller, if
you use X11 please install xf86-video-vmware or bypass the usage of
vmsvga with the following lines in your Vagrantfile:

config.vm.provider "virtualbox" do |vb|
  vb.customize ['modifyvm', :id, '--graphicscontroller', 'vboxvga']
end

or with the newer vboxsvga graphic controller:

config.vm.provider "virtualbox" do |vb|
  vb.customize ['modifyvm', :id, '--graphicscontroller', 'vboxsvga']
end
--------------------------------------------------------------------
MSG

Vagrant.configure("2") do |config|
  config.vm.post_up_message = $msg
end
