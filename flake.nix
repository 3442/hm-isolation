{
  description = "Home Manager isolation";

  outputs = { self }: {
    homeManagerModule = self.homeManagerModules.isolation;
    homeManagerModules.isolation = import ./module.nix;
  };
}
