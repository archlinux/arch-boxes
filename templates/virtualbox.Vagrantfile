# -*- mode: ruby -*-
# vi: set ft=ruby :

$msg = <<MSG
--------------------------------------------------------------------
This box uses Virtualbox > 6.0 standards for the graphic controller,
if you use X11 in the guest please also install xf86-video-vmware
inside your VM (auto-resizing might not work, even with
xf86-video-vmware installed) or bypass the usage of vmsvga with the
following lines in your Vagrantfile:

config.vm.provider "virtualbox" do |vb|
  vb.customize ['modifyvm', :id, '--graphicscontroller', 'vboxvga']
end

or with the newer vboxsvga graphic controller:

config.vm.provider "virtualbox" do |vb|
  vb.customize ['modifyvm', :id, '--graphicscontroller', 'vboxsvga']
end

If you use Virtualbox < 6.0 you can safely ignore this message.
--------------------------------------------------------------------
MSG

Vagrant.configure("2") do |config|
  config.vm.post_up_message = $msg
end
