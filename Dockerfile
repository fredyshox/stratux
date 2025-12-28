# Image for building Stratux
#
FROM debian:trixie

# file and nano are nice to have
RUN apt-get update \
  && apt-get -y install file \
  && apt-get -y install nano \
  && apt-get -y install make \
  && apt-get -y install git \
  && apt-get -y install gcc \
  && apt-get -y install ncurses-dev \
  && apt-get -y install golang-go \
  && apt-get -y install wget \
  && apt-get -y install libusb-1.0-0-dev \
  && apt-get -y install pkg-config \
  && apt-get -y install librtlsdr0 \
  && apt-get -y install librtlsdr-dev \
  && apt-get -y install build-essential

# specific to debian, ubuntu images come with user 'ubuntu' that is uid 1000
ENV USERNAME="stratux"
ENV USER_HOME=/home/$USERNAME

RUN useradd -m -d $USER_HOME -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
