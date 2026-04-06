FROM debian:trixie as debuilder

ENV DEBIAN_REF=2026-04-06_11:33
ENV FOOTPRINT_REF=486aa6dc81f13cb98efddd2fe0026d1db145d20b
ENV FPINDEX_REF=4a821566bdafd38163d6731722549eb57edfe670
ENV IASINAT_REF=5559364282f0f8de61d1ea9195e872c39b4b73be
ENV COINCIDENCE_REF=07a2be5d7ed9c0fd4fb42639b1b22262aaf20db8

RUN echo "// $DEBIAN_REF" >/etc/apt/apt.conf.d/00fakedep
RUN echo 'APT::Install-Recommends "0";' >/etc/apt/apt.conf.d/10norec
RUN echo 'APT::Install-Suggests "0";' >/etc/apt/apt.conf.d/10nosug
RUN echo 'deb-src https://deb.debian.org/debian/ trixie main' >/etc/apt/sources.list.d/sources.list
RUN apt -y update
RUN apt -y build-dep zsh
RUN apt -y install zsh curl libnetcdf-dev libhdf5-dev
RUN apt -y install ca-certificates

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN apt -y install git

ENV PATH=/root/.cargo/bin:$PATH

RUN git clone https://github.com/berke/footprint.git
WORKDIR footprint
RUN git branch work $FOOTPRINT_REF
RUN git checkout work
RUN cargo build --release -F stac -p fptool
RUN install target/release/fptool /usr/local/bin
RUN install target/release/stac2fp /usr/local/bin

WORKDIR /root
RUN git clone https://github.com/berke/fpindex.git
WORKDIR fpindex
RUN git branch work $FPINDEX_REF
RUN git checkout work
RUN cargo build --release -p fpindex-tool
RUN install target/release/fpindex-tool /usr/local/bin

WORKDIR /root
RUN git clone https://github.com/berke/iasinat.git
WORKDIR iasinat
RUN git branch work $IASINAT_REF
RUN git checkout work
RUN cargo build --release -F footprints-mpk -p iasinat-tool
RUN install target/release/iasinat-tool /usr/local/bin

WORKDIR /root
RUN git clone https://github.com/berke/coincidence.git
WORKDIR coincidence
RUN git branch work $COINCIDENCE_REF
RUN git checkout work
WORKDIR downloader
RUN cargo build --release --bin tropomifpex --bin downloader --bin intersect
RUN install target/release/intersect /usr/local/bin
RUN install target/release/tropomifpex /usr/local/bin
RUN install target/release/downloader /usr/local/bin