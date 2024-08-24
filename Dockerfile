FROM docker.io/library/rust:1.80

# NB: this dockerfile expects to be run using rootless podman with
# the --userns=keep-id, and may not work with normal root-user
# containers.  See run.sh for how it is normally run.

ARG USERNAME
ARG UID
ARG GID

# This should be a mounted from your source dir into the container
RUN mkdir -p /home/$USERNAME/src

# This should be mounted from somewhere else into your container to
# save compile time; I like to use ~/.local/rust_local_[name]
RUN mkdir -p /home/$USERNAME/.cargo

RUN mkdir -p /home/$USERNAME/.config

RUN mkdir -p /home/$USERNAME/bin
RUN ln -s /usr/local/cargo/bin/* /home/$USERNAME/bin/

RUN chown -R $UID:$GID /home/$USERNAME

ENV HOME=/home/$USERNAME
ENV CARGO_HOME=/home/$USERNAME/.cargo

# Packages all in one blob for the usual container reasons
#
# Various utility packages
#
# See cargo_config.toml for why mold is here
#
# Stuff required by neovim kickstart
RUN apt-get update && apt-get install -y less vim openssh-server git make locales locales-all curl wget \
    lld clang mold \
    gcc ripgrep unzip
# python3-pip npm nodejs

COPY watch.sh /home/$USERNAME/bin/watch

COPY cargo_config.toml /var/tmp/cargo_config.toml

RUN echo "cp /var/tmp/cargo_config.toml ~/.cargo/config.toml" > /home/$USERNAME/.bothrc-local
RUN echo "cd \$SRC_DIR" >> /home/$USERNAME/.bothrc-local

## If you want to use beta:
##
## RUN rustup toolchain install beta
## RUN rustup default beta
## RUN rustup toolchain list | grep -v beta | xargs rustup toolchain uninstall
## RUN rustup set auto-self-update enable
## RUN rustup update
## RUN rustup component add rust-src
## RUN rustup component add rustfmt
## RUN rustup component add clippy
## RUN rustup component add rust-analyzer
## RUN cargo install cargo-watch
## RUN cargo install cargo-tarpaulin
## RUN cargo install cargo-audit

RUN rustup component add rust-src
RUN rustup component add rustfmt
RUN rustup component add clippy
RUN rustup component add rust-analyzer
RUN cargo install cargo-watch
RUN cargo install cargo-tarpaulin
RUN cargo install cargo-audit

# Now we install nvim
RUN cd /tmp && wget https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz && \
    rm -rf /opt/nvim-linux64 && \
    mkdir -p /opt/nvim-linux64 && \
    chmod a+rX /opt/nvim-linux64 && \
    tar -C /opt -xzf nvim-linux64.tar.gz && \
    ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/
