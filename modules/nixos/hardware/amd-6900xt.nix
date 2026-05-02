{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.amdgpu_top
    pkgs.vulkan-tools
  ];
}
