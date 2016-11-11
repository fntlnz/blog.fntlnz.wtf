+++
date        = "2016-11-11T01:38:22+02:00"
title       = "Using systemd-nspawn for my laptop's containerization needs"
description = "Personal considerations on using systemd-nspawn for a project and for applications in my laptop"
tags        = [ "containers", "systemd", "systemd-nspawn" ]
topics      = [ "containers", "systemd", "systemd-nspawn" ]
slug        = "systemd-nspawn"
+++

## Why I started using `systemd-nspawn`

Anyone who knows me knows that I use containers for basically everything, starting from my
own laptop up to production clusters counting gazillion of nodes.

And, few weeks ago, while talking with some of my colleagues about a super secret product we are developing which needs to take advantage
of typical containers' isolation features the focus obviously started thinking about Docker.

*But, here comes the thing:*

![cereals meme](/systemd-nspawn/cereals.png)

I can't say much, but our product is a set of tiny tools which makes use of containers to do their tasks, but, by design, those tiny objects needs to be as small as possible and should have nearly zero dependencies upon external tools.

So, at first, we put on the table the possibility to use [Runc](https://github.com/opencontainers/runc) instead of Docker and specifically we choose
to embed [libcontainer](https://github.com/opencontainers/runc/tree/master/libcontainer) as a library in our code to create containers by our own.

But, In the past few years I matured a special attention on systemd, so I started considering the possibility to use of this `systemd-nspawn` thing instead of libcontainer for our product.

The first thing I did was to **conduct a few tests** based on my needs and here's a shortlist of my considerations:

- `systemd-nspawn` perfectly fits my containerization needs of my project, I don't need a cluster, I don't need Windows or Solaris support, I don't need apparmor, I don't need an union filesystem.
- AFAIK has been started [in 2011](https://github.com/systemd/systemd/blob/88213476187cafc86bea2276199891873000588d/src/nspawn.c), yes it was very basic at that time but, you know.
- [Now](https://github.com/systemd/systemd/tree/7debb05dbe1f157e5f07c9bffa98fbe33e1b514e/src/nspawn) is a well structured project, with readable code and all the features I need: isolation, macvlan/ipvlan, cgroups, seccomp, capabilities
- `systemd-nspawn`, I don't need a replacement for Docker, it has a plethora of things I need in the 99% of situations

Said this, **I will not** use the `systemd-nspawn` command line tool in our project but rather **I will use it as a library** but this is another story, the prelude was just
to give a motivation on why I started using `systemd-nspawn` for my laptop's containers after all.


# What kind of laptop's containerization needs?
When I say that I containerize all my laptop needs I mean that I just install my chosen OS, Fedora Workstation and as everyone on top of that I just install some applications I need
to work, like a browser, neovim and spotify of course.

The fact is that I don't want to install any software on my laptop, I want to run a container instead and a possible solution to run my containers may be systemd-nspawn.

**WHAT'S NOT INCLUDED?**

Obviously here we are only talking about the applications I use on my laptop, I still use Docker on my laptop when I write software that's shipped as containers, obviously.


**HEY!**: from now on I will show a few examples, Dockerfiles commands and other things I tested only on my Fedora Workstation 24, kernel 4.4 which has systemd.
Don't expect for the examples to work out-of-the-box in your laptop, **they might or not**.

At first we can start by takeing looking at the [runc example](https://github.com/opencontainers/runc#running-containers) to create an image.
We can do the same thing for nspawn, so, to create a busybox container:

**nspawn version**

```bash
# create the top most bundle directory
mkdir /mycontainer
cd /mycontainer

# create the rootfs directory
mkdir rootfs

# export busybox via Docker into the rootfs directory
docker export $(docker create busybox) | tar -C rootfs -xvf -
```

And then we can run it with `systemd-nspawn`

```
sudo systemd-nspawn -D rootfs/
```

Let's try something harder, here's **how I containerize spotify**, for example using nspawn.

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
mkdir spotify-nspawn
cd spotify-nspawn

mkdir rootfs
docker export $(docker create fntlnz/spotify) | tar -C rootfs -xvf -
```

Then we have to give the right permissions to `/home/spotify`

```bash
sudo systemd-nspawn -D rootfs/ bash -c "chown -R spotify:spotify /home/spotify"
```

So that we can start the container and join the sound: 

```bash
sudo systemd-nspawn \
	--setenv=DISPLAY=unix$DISPLAY \
	--bind=/tmp/.X11-unix:/tmp/.X11-unix \
	--bind /run/user/1000/pulse:/run/pulse \
	--bind /var/lib/dbus:/var/lib/dbus \
	--bind $HOME/.spotify/config:/home/spotify/.config/spotify \
	--bind $HOME/.spotify/cache:/home/spotify/spotify \
	-u spotify -D rootfs/ \
	spotify
```

And as because I'm using [i3](https://i3wm.org/) I just added that script to `/usr/local/bin/spotify` and here's the result (click to open the image)

[![Spotify on systemd-nspawn](/systemd-nspawn/video.gif)](/systemd-nspawn/video.gif)
