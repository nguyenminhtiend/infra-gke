#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf "[phase0-install] %s\n" "$*"; }
err() { printf "[phase0-install][error] %s\n" "$*" 1>&2; }
has() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"
ARCH="$(uname -m)"

install_mac() {
  if ! has brew; then
    log "Installing Homebrew (required on macOS)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    log "Homebrew found: $(brew --version | head -n1)"
  fi

  log "Updating Homebrew"
  brew update

  log "Installing Google Cloud SDK"
  brew install --cask google-cloud-sdk || true

  log "Installing core tooling"
  brew install terraform kubernetes-cli helm argocd jq yq || true

  if has gcloud; then
    log "Ensuring GKE auth plugin is available"
    gcloud components install gke-gcloud-auth-plugin -q || true
  fi

  log "Installed versions:"
  gcloud --version || true
  terraform -version || true
  kubectl version --client=true --output=yaml || true
  helm version --short || true
  argocd version --client || true
}

install_linux_debian() {
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release

  log "Adding HashiCorp APT repo (Terraform)"
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

  log "Adding Google Cloud CLI APT repo"
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null

  log "Adding Helm APT repo"
  curl -fsSL https://baltocdn.com/helm/signing.asc | sudo gpg --dearmor -o /usr/share/keyrings/helm.gpg
  echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null

  sudo apt-get update -y
  sudo apt-get install -y google-cloud-cli google-cloud-sdk-gke-gcloud-auth-plugin terraform helm jq

  local kubectl_url arch_bin
  case "${ARCH}" in
    x86_64|amd64) arch_bin=amd64;;
    aarch64|arm64) arch_bin=arm64;;
    *) err "Unsupported CPU arch for kubectl: ${ARCH}"; exit 1;;
  esac
  kubectl_url="https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/${arch_bin}/kubectl"
  log "Installing kubectl (latest stable) from ${kubectl_url}"
  curl -fsSLo /tmp/kubectl "${kubectl_url}"
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl

  local argocd_url
  case "${ARCH}" in
    x86_64|amd64) argocd_url="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64";;
    aarch64|arm64) argocd_url="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-arm64";;
  esac
  log "Installing Argo CD CLI from ${argocd_url}"
  curl -fsSLo /tmp/argocd "${argocd_url}"
  chmod +x /tmp/argocd
  sudo mv /tmp/argocd /usr/local/bin/argocd

  log "Installed versions:"
  gcloud --version || true
  terraform -version || true
  kubectl version --client=true --output=yaml || true
  helm version --short || true
  argocd version --client || true
}

case "${OS}" in
  Darwin)
    install_mac
    ;;
  Linux)
    if [ -r /etc/os-release ]; then
      . /etc/os-release
      if echo "${ID_LIKE:-}${ID:-}" | grep -qiE 'debian|ubuntu'; then
        install_linux_debian
      else
        err "Linux distro not supported by this script. Please install tools manually."
        exit 1
      fi
    else
      err "/etc/os-release not found; cannot detect Linux distro"
      exit 1
    fi
    ;;
  *)
    err "Unsupported OS: ${OS}"
    exit 1
    ;;
esac

log "Done. Next: run gcloud auth login && gcloud auth application-default login"

