{
  lib,
  kubernetes,
  runCommandLocal,
}: let
  extractBin = b:
    runCommandLocal "k8s-${b}" {} ''
      mkdir $out/bin/
      cp ${kubernetes}/bin/${b} $out/bin/${b}
    '';
in {
  kube-controller-manager = extratBin "kube-controller-manager";
  kube-scheduler = extratBin "kube-scheduler";
  kube-proxy = extratBin "kube-proxy";
  kubelet = extratBin "kubelet";
  kube-apiserver = extractBin "kube-apiserver";
  kubectl = extractBin "kubectl";
  kube-addons = extractBin "kube-addons";
  kubeadm = extractBin "kubeadm";
}
