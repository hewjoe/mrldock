FROM ubuntu:jammy as builder

COPY myrobotlab.zip /tmp/myrobotlab.zip
RUN apt-get update && \
    apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      unzip \
      openjdk-11-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN unzip -j /tmp/myrobotlab.zip -d /opt/myrobotlab && \
    rm /tmp/myrobotlab.zip 

ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

COPY --chown=root:root cache/ /root/

RUN cd /opt/myrobotlab && \
    java -jar /opt/myrobotlab/myrobotlab.jar --install
COPY myrobotlab.sh /opt/myrobotlab/myrobotlab.sh

FROM ubuntu:jammy

RUN apt-get update && \
    apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      unzip \
      git \
      sudo \
      wget \
      openjdk-11-jdk \
      python3-pip \
      python3.10-venv \
      tigervnc-standalone-server \
      tigervnc-xorg-extension \
      dbus \
      dbus-x11 \
      gnome-keyring \
      xfce4 \
      xfce4-terminal \
      xdg-utils \
      x11-xserver-utils \
      alsa-base \
      alsa-utils \
      gstreamer1.0-alsa \
      gstreamer1.0-pulseaudio \
      libgsound0 \ 
      libpcaudio0 \
      linux-sound-base \
      pciutils \
      pulseaudio-module-bluetooth \
      sound-icons \
      speech-dispatcher-audio-plugins \
      yaru-theme-sound && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create the user that will run the application
RUN useradd -m -G sudo,dialout,plugdev,audio,users,input,kvm,bluetooth,avahi,pulse,pulse-access,video -s /bin/bash mrladm \
    && sed -i -e '/Defaults\tuse_pty/d' -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers && \
    echo mrladm:InM00vROX | chpasswd


# Install novnc and numpy module for it
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/novnc \
	&& git clone --depth 1 https://github.com/novnc/websockify /opt/novnc/utils/websockify \
	&& find /opt/novnc -type d -name '.git' -exec rm -rf '{}' + 
COPY novnc-index.html /opt/novnc/index.html
COPY mrl-vncsession /usr/bin/
# Add X11 dotfiles
COPY --chown=mrladm:mrladm .xinitrc /home/mrladm/.xinitrc

# chrome and basic render font
# google-chrome
# misc deps for electron and puppeteer to run
RUN cd /tmp && glink="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
	&& wget -q "$glink" \
	&& apt update && \
    apt-get install -y \
      libasound2-dev \
      libgtk-3-dev \
      libnss3-dev \
	  fonts-noto \
      fonts-noto-cjk \
      ./"${glink##*/}" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
	\
	# OLD: && ln -srf /usr/bin/chromium /usr/bin/google-chrome
	# OLD: To make ungoogled_chromium discoverable by tools like flutter
	&& ln -srf /usr/bin/google-chrome /usr/bin/chromium \
	\
	# Extra chrome tweaks
	## Disables welcome screen
	&& t="$/home/mrladm/.config/google-chrome/First Run" && sudo -u mrladm mkdir -p "${t%/*}" && sudo -u mrladm touch "$t" \
	## Disables default browser prompt
	&& t="/etc/opt/chrome/policies/managed/managed_policies.json" && mkdir -p "${t%/*}" && printf '{ "%s": %s }\n' DefaultBrowserSettingEnabled false > "$t"

# For Qt WebEngine on docker
ENV QTWEBENGINE_DISABLE_SANDBOX 1

# Install MyRobotLab built in "builder" stage
COPY --from=builder --chown=mrladm:mrladm /opt/myrobotlab /opt/myrobotlab

USER mrladm

RUN python3 -m venv /opt/myrobotlab/venv && \
    /opt/myrobotlab/venv/bin/pip3 install --no-cache-dir --upgrade pip wheel && \
    /opt/myrobotlab/venv/bin/pip3 install --no-cache-dir py4j numpy 

ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

EXPOSE 8888
EXPOSE 5900
EXPOSE 6080

WORKDIR /opt/myrobotlab

ENTRYPOINT [ "/bin/bash", "-c", "/opt/myrobotlab/myrobotlab.sh" ]
