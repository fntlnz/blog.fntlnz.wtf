+++
date        = "2016-11-11T01:38:22+02:00"
title       = "Using systemd-nspawn for some containerization needs"
description = "Personal considerations on using systemd-nspawn to save my laptop"
tags        = [ "containers", "systemd", "systemd-nspawn" ]
topics      = [ "containers", "systemd", "systemd-nspawn" ]
slug        = "systemd-nspawn"
+++

# SCALETTA

- Problema da risolvere
- Docker perfetto per tutto ma lento e non voglio tutte le sue features isolation etch in tutte le situa
- che cosa è systemd-nspawn
- che cosa è machinectl
- esempi e benchmark
- conclusioni


About one year ago, after years with Fedora 18, I refreshed my laptop and installed a brand new Fedora 22.
My first thought went to all the mess there was before the refresh, I tried tons of applications and changed my mind thousands of times
in those three years.

After a few minutes thinking I had a light-bulb moment and I just started creating a Dockerfile for every application I needed.

Well, after some time I had 27 images including:

- google-chrome
- spotify
- dropbox
- NetworkManager
- pulseaudio
- gnome-terminal-server
- nautilus
- feh
- i3wm
- lightdm
- crond
- VirtualBox
- compton
- parcellite
- guake
- and... many more!

As you can imagine, I started each one with the right options allowing it to use the X server or the devices.

In the next days I did some fine tuning and ended up having all the containers I listed starting at boot except for *google-chrome* and *nautilus*.

What happened ?: My computer **took minutes** to **undefined time** to boot depending on the state of the Docker daemon, now, as you may understand that 
was everything but desirable for me so I started thinking on what to do next.

The main problem for me wasn't that the Docker daemon itself is slow (in fact it's not) but a mix of factors due to the fact that Docker is a daemon and being a daemon it has its own list of checks/things to do at startup like setting up namespaces for existing containers, setting up volumes, managing and connecting to plugins, mounting the layered filesystems, setting up missing network devices and so on..

All this obviously slows down startup times in certain situations and given the fact that I use docker *a lot* for software development and for docker development itself there are a lot of possibilities that the state of my machine Docker daemon is pretty messy and things are likely to be broken and slow.


## Starting a Spotify container using systemd-nspawn

Let's say that I need to listen to some music and I'm on Fedora.

I Google for the Spotify Linux client aaaaand that's IT! Spotify does have a Linux client, great! 

Oh, damn, **they only have a Debian package** :(

...Looking for possible solutions...

**IDEA!:** I can put it in a Docker container! Yeah, but I just want to listen music, do I really need a running daemon, and network isolation,
and all the other cool things that come with Docker? NOPE, as said, I just wanted to listen to some music.

So the first thing I did was in fact to create a Dockerfile for spotify.

**Q:** Wait Lorenzo, but you've just said you are not using Docker for your listening needs.
**A**: In fact I don't, I'm just using Docker to create a Docker image, which I will export to a tar and use as a base filesystem for my container

Here's the Dockerfile:

```Dockerfile
FROM debian:jessie

RUN apt-get update -y
RUN gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys BBEBDCB318AD50EC6865090613B00F1FD2C19886
RUN gpg --export --armor BBEBDCB318AD50EC6865090613B00F1FD2C19886 | apt-key add -
RUN echo deb http://repository.spotify.com stable non-free | tee /etc/apt/sources.list.d/spotify.list
RUN apt-get update -y
RUN apt-get install spotify-client -y
RUN apt-get install pulseaudio -y
RUN apt-get install -f -y
RUN echo enable-shm=no >> /etc/pulse/client.conf

ENV PULSE_SERVER /run/pulse/native
ENV HOME /home/spotify
RUN useradd --create-home --home-dir $HOME spotify \
  && gpasswd -a spotify audio \
    && chown -R spotify:spotify $HOME

    WORKDIR $HOME
    USER spotify
    ENTRYPOINT  [ "spotify" ]

```

After building it with name `fntlnz/spotify` it can be run in Docker with:

```bash
 docker run -d \
	 -v /etc/localtime:/etc/localtime:ro \
	 -v /tmp/.X11-unix:/tmp/.X11-unix \
	 -e DISPLAY=unix$DISPLAY \
	 -v /run/user/1000/pulse:/run/pulse:ro \
	 -v /var/lib/dbus:/var/lib/dbus \
	 -v $HOME/.spotify/config:/home/spotify/.config/spotify \
	 -v $HOME/.spotify/cache:/home/spotify/spotify \
	 --name spotify \
	 fntlnz/spotify
```

Now that I have my image and I can use it with Docker seeing that it works I can try it with `systemd-nspawn`

The first thing to do is to export the docker image to a folder we'll call `rootfs`

```bash
mkdir containers
cd containers

mkdir spotify
docker export $(docker create fntlnz/spotify) | tar -C spotify -xvf -
```

Then we have to give the right permissions to `/home/spotify`

```bash
sudo systemd-nspawn -D spotify/ bash -c "chown -R spotify:spotify /home/spotify"
```

Now each time we want to start that container we can do it with:

```bash
sudo systemd-nspawn \
	--setenv=DISPLAY=unix$DISPLAY \
	--bind=/tmp/.X11-unix:/tmp/.X11-unix \
	--bind /run/user/1000/pulse:/run/pulse \
	--bind /var/lib/dbus:/var/lib/dbus \
	-u spotify -D spotify/ \
	spotify
```

### Things to note:

- We haven't used any layered filesystem and the container is actually writing into the `spotify` directory.
- The network stack is not isolated
- The **1000** user id needs to be changed with the id of the user connected to the X session (your user id on that machine)





# What I achieved ?

- **Portability**: most linux distributions today are using systemd that means that my containers will work without having to install anything
- **Faster startup times**: as I said, starting just a process is faster than setting up a Docker container, not because Docker is slow (it's not) but because it does actually more than just starting the process
