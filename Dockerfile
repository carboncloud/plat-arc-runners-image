FROM public.ecr.aws/ubuntu/ubuntu:24.04


ARG TARGETPLATFORM
ARG RUNNER_VERSION=2.331.0
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.8.0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt-get install -y git bash wget ca-certificates curl unzip skopeo buildah gnupg jq yq xz-utils sudo tini && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

RUN adduser --disabled-password --gecos "" --uid 1001 runner \
  && usermod -aG sudo runner \
  && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
  && mkdir /nix \
  && chown runner /nix 

USER runner
ENV USER=runner
ENV PATH="/home/runner/.nix-profile/bin:${PATH}"
ENV HOME="/home/runner"
RUN curl -sL https://nixos.org/nix/install | sh -s -- --no-daemon

RUN export PATH="$PATH:/nix/var/nix/profiles/default/bin" \
  && nix profile add --extra-experimental-features nix-command --extra-experimental-features flakes --accept-flake-config nixpkgs#cachix \
  && sudo cp ~/.nix-profile/bin/cachix /usr/bin/cachix 

RUN sudo install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && sudo chmod a+r /etc/apt/keyrings/docker.gpg \
  && echo "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \"$(. /etc/os-release && echo \"$VERSION_CODENAME\")\" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && sudo apt-get update \
  && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  && sudo groupmod -g 123 docker \
  && sudo usermod -a -G docker runner

WORKDIR /home/runner
RUN wget https://github.com/aquasecurity/trivy/releases/download/v0.68.2/trivy_0.68.2_Linux-64bit.deb \
  && sudo dpkg -i trivy_0.68.2_Linux-64bit.deb \
  && rm trivy_0.68.2_Linux-64bit.deb

RUN (type -p wget >/dev/null || (sudo apt-get update && sudo apt-get install wget -y)) && sudo mkdir -p -m 755 /etc/apt/keyrings && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && sudo apt update && sudo apt install gh -y

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip \
  && unzip awscliv2.zip \
  && sudo ./aws/install \
  && rm -rf ./aws \
  && rm -rf ./awscliv2.zip 


# Runner download supports amd64 as x64
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "amd64" ]; then export ARCH=x64 ; fi \
    && curl -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz \
    && sudo ./bin/installdependencies.sh \
    && sudo apt-get autoclean \
    sudo apt-get autoremove
