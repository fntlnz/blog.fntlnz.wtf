+++
date        = "2016-11-11T01:38:22+02:00"
title       = "Using systemd-nspawn for some containerization needs"
description = "Personal considerations on the usage of systemd-nspawn for desktop applications and system services"
tags        = [ "containers", "systemd", "systemd-nspawn" ]
topics      = [ "containers", "systemd", "systemd-nspawn" ]
slug        = "systemd-nspawn"
+++

About one year ago, after years with Fedora 18, I refreshed my laptop and installed a brand new Fedora 22.
My first thought went to all the mess there was before the refresh because I tried tons of applications and changed my mind thousands of times
in those three years.

This time, I wanted to take my time to **improve the process** and after a few minutes thinking I had a light-bulb moment and I just started creating **a Dockerfile for every application** I needed !

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

As you can imagine, I started each one with the right options (**I hope!**) allowing it to use the X server and other resources.

In the next days I did some fine tuning and ended up having most of the containers I listed starting as startup system services.

### What happened ?

My computer **took minutes** to **undefined time** to boot depending on the state of the Docker daemon, and that wasn't acceptable for me so, sad but full of hope I started thinking at a possible solution
by identifying why Docker wasn't performing well as I expected in such situation.

The main problem, wasn't that the Docker daemon itself is slow (in fact it isn't) but a mix of factors due to the intrinsic docker's caracteristic that **it wants to manage** everything for you, like setting up namespaces for existing containers, setting up volumes, managing and connecting to plugins, mounting the layered filesystems, setting up missing network devices and so on..

All this obviously slows down startup times in certain situations and given the fact that I use docker *a lot* for software development and for docker development itself there are a lot of ways that the state of my machine Docker daemon is pretty messy and things are likely to be broken and slow.


# Example container: Spotify

Let's say that I need to listen to some music and I'm on Fedora (looks like me now :D)

I Google for the Spotify Linux client aaaaand that's IT! Spotify does have a Linux client, great! 

Oh, damn, **they only have a Debian package** :(

...Looking for possible solutions...

So the first thing I did was in fact to create a Dockerfile for spotify.

**Q:** Wait Lorenzo, but **you've just said you are not using Docker** for your listening needs.
**A**: In fact **I don't**, I'm just using Docker to create a Docker image, which I will export to a tar and use as a base filesystem for my container

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
# docker run -d \
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
# mkdir -p /var/lib/machines
# cd /var/lib/machines

# mkdir spotify
# docker export $(docker create fntlnz/spotify) | tar -C spotify -xvf -
```

Then we have to give the right permissions to `/home/spotify`

```bash
# systemd-nspawn -D spotify/ bash -c "chown -R spotify:spotify /home/spotify"
```

Now each time we want to start that container we can do it with:

```bash
# systemd-nspawn \
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
- I'm not mounting `$HOME/.spotify` things inside my `systemd-nspawn` container since I decided to keep the state in the `spotify` directory



# machinectl

There's another tool, invokable via `machinectl` which allows you to manage your "machines" aka containers and vms managed
by the [**systemd machine manager**](https://wiki.freedesktop.org/www/Software/systemd/machined/)

#### Container services

Using machinectl you can even create startup services, for example I use this for the NetworkManagr (image not included)

```bash
# machinectl enable network-manager

Created symlink from /etc/systemd/system/machines.target.wants/systemd-nspawn@network-manager.service to /usr/lib/systemd/system/systemd-nspawn@.service.
```

#### Management
machinectl allows you to list, terminate and show the status of machines.

```bash
# machinectl list


MACHINE CLASS     SERVICE
spotify container nspawn 

1 machines listed.
```

```bash
# machinectl terminate spotify
```

```bash
# machinectl status spotify

spotify
           Since: Mon 2016-11-14 02:13:54 CET; 7s ago
          Leader: 11308 (spotify)
         Service: nspawn; class container
            Root: /var/lib/machines/spotify
              OS: Debian GNU/Linux 8 (jessie)
            Unit: machine-spotify.scope
                  ├─11308 /usr/share/spotify/spotif
                  ├─11321 /usr/share/spotify/spotify --type=zygote --no-sandbox --lang=en-US --log-file=/usr/share/spotify/debug.log --log-severity=disable --product-version=Spotify/1.0.42.151
                  ├─11344 /proc/self/exe --type=gpu-process --channel=1.0.1413324922 --mojo-application-channel-token=7BA7725BB9581D934FDAECBCAC0E2C8B --no-sandbox --window-depth=24 --x11-visual-id=32 --lang=en-
                  └─11372 /usr/share/spotify/spotify --type=renderer --disable-pinch --no-sandbox --primordial-pipe-token=431AFC3F7268B33A8765213F7926A54A --lang=en-US --lang=en-US --log-file=/usr/share/spotify/

Nov 14 02:13:54 fntlnz systemd[1]: Started Container spotify.
Nov 14 02:13:54 fntlnz systemd[1]: Starting Container spotify.
```

#### Pull images

machinectl can pull images using `pull-raw`, `pull-tar` and `pull-dkr` from remote urls.

```
# machinectl pull-raw --verify=no http://ftp.halifax.rwth-aachen.de/fedora/linux/releases/21/Cloud/Images/x86_64/Fedora-Cloud-Base-20141203-21.x86_64.raw.xz
# systemd-nspawn -M Fedora-Cloud-Base-20141203-21
```

for more, see [machinectl](https://www.freedesktop.org/software/systemd/man/machinectl.html)


## What's next

In this post I showed you something like the top 1% of the things that can be done with `systemd-nspawn`, there's **moar!!**, like:

- Usage of btrfs as container root and ephemeral containers
- Network isolation and advanced network interfaces (macvlan, ipvlan)
- Integration with SELinux
- bootable images


see `man machinectl` and `man systemd-nspawn` for more

# What I achieved ?

- **Portability and zero setup time**: most linux distributions today are using systemd that means that my containers will work without having to install anything
- **Faster startup times**: as I said, starting just a process is faster than setting up a Docker container, not because Docker is slow (it's not) but because it does actually more than just starting the process
- **Reuse**: I can reuse any docker image I want just by exporting it to a tar file, I can even reuse virtual machine images.


Now let's listen at some music!

![systemd nspawn spotify](/systemd-nspawn/video.gif)
