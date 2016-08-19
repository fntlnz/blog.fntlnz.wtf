+++
date        = "2016-08-11T15:22:27-04:00"
title       = "Why do we have containers"
description = "Speculations on why we do have containers"
tags        = [ "post" ]
topics      = [ "post" ]
slug        = "why-containers"
+++


## Disclaimer

This post reflects my own view of the whole world of virtualization, I summed up here my thoughts but please
if you find something that you consider wrong or inexact leave a comment so I can learn by you and improve myself. 🤘🏼


## Introduction

As part of my work at [Kiratech](http://www.kiratech.it/) I evangelize people about [OS level Virtualization](https://en.wikipedia.org/wiki/Operating-system-level_virtualization)
and, while talking about Linux Containers, Docker Containers or more in general about the **concept of containers itself** I often (as it should be) encounter doubts and questions like:

- What is the actual difference between containers and other types of virtualization?
- How are containers going to make my life better?
- What should I say to my security team while I'm using those containers?

All this can be summarized in a more simple question:

> Why do we have containers ? What we had before was not enough?


In this post I want to try to explain why, in my opinion, **OS Level Virtualization** (aka. containers) is a thing that matters now
primarily by analyzing the details of each virtualization method.

## Different types of virtualization

At the moment there are three main distinct types of Virtualization, namely:

- Full Virtualization
- Paravirtualization
- OS Level Virtualization (Containers)


The most interesting one for the discussion is the last one but is important to understand that at some extent all types have two common denominators:

![](/why-containers/Virtualization.png)

- A Host: the primary operating system where the Docker daemon is running, where KVM is running, where VMware is running
- A Guest: the actual container or virtual machine

The main difference between all those types of virtualization is the level at which them interact with the underlying resources and devices
thus is responsible for their difference in terms of security, resources usage and portability.

This discussion can be easily understood in the context of load balancers where there two types of them: Hardware and software load balancers,
both do load balancing and while the hardware version typically provides improved performances this comes at the cost of another specific piece of hardware with the limitations of the case.
as opposite, software load balancers can be installed on any hardware, are more portable, customizable and probably fits better specific needs.


Given all this, there are a few areas of differentiation between all the different types of virtualization:

- **Security**: Having a full operating system with its own kernel may seem a source of additional security because of the fact
that is nearly impossible to escape from virtual machines. But if you consider the fact that you are putting a **brand new kernel, with its vulnerabilities
and bugs** on top of your existing kernel you may change your point of view. On the other hand, OS-Level virtualization share the same kernel with the host operating system
but comes with a larger surface for possible attackers due to the syscalls, shared networking, device and disk access. Anyway don't worry most of these security issues are
solved in most used OS-Level virtualization platforms such as Docker, in fact Docker Containers for example are fully integrated with cgroups, seccomp, SELinux, and all the possible resources
are isolated properly using Kernel namespaces, also you can manually add or drop capabilities.
- **Portability**: Full virtualization and paravirtualization both leverages on specific hardware, because of its nature requires more resources than
OS-Level virtualization which can be used anywhere a modern Linux kernel is present.
- **Speed**: The fact that OS-Level virtualization works in a shared kernel architecture offers super fast startup times, this is not true for other types of virtualization
where starting a new system is a lot more than just spawning a new process as it is with containers.
- **Application Portability**: as because containers can be moved easily due to their decreased size due to the fact that they don't own an entire operating system and a kernel
we can obtain **reduced downtimes** and avoid headaches. For other types of virtualization this is not true, we all know that moving a virtual machine to another
host requires lots of bandwidth and storage.
- **Storage**: given that OS-Level virtualization implies the fact that the kernel is shared usually there's an implemented Copy on Write filesystem and Union Filesystem
to put all the pieces toghether and obtain containers that only owns their code, components and libraries.
- **Live Migration**: Some OS-Level virtualization platform such as OpenVZ does support live migrations, most Fill virtualization platforms supports it. Docker containers on the
other hand does not have an official implementation for this


## Motivations for using Containers

I can't know what is your intended use case.
But if at some extent your motivation consist in **decreasing costs** related to full virtualization overheads
while **allowing developers to ship, develop and test code faster** we already found two.


## In the end, why containers are actually there?

If you'v read up to here you probably think I missed the point, instead what I wanted to write is exactly that
OS-Level virtualization (aka containers) is just another way of doing virtualization which solves specific needs that are not solved by others:

**If you need a recap, here you go:**

We need containers for being able to work closer to the kernel while executing in a fully isolated environment.
This specific thing allows us to achieve **higher densities** and run more workload within the same hardware while
obtaining **faster delivery and scaling** thanks to their nature of high portability.

