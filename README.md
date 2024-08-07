# Devopsfetch
**[View Detailed documentation here](https://github.com/laraadeboye/devopsfetch/wiki)** \
Devopsfetch is a shell script tool designed for system information retrieval and monitoring. It collects and displays system information, including active ports, Docker images and containers, Nginx domains and configurations, and user login times. The tool supports continuous monitoring with logging, detailed error handling, and can be installed as a systemd service.

## Features

- Display all active ports and services
- List all Docker images and containers
- Display all Nginx domains and their ports
- List all users and their last login times
- Display activities within a specified time range
- Continuous monitoring with logging
- Systemd service for automatic startup

## Requirements

- Ubuntu or Debian-based system
- Root privileges or elevated privileges (using sudo)
  
You can switch to the root user by running:
```bash
sudo su
```
or run `sudo <command>` where `<command>` represents the command you want run.
```bash
sudo devopsfetch -h
```

## Installation

### Clone the Repository

First, clone the repository to your local machine:

```bash
git clone https://github.com/laraadeboye/devopsfetch.git
cd devopsfetch
```

## Install Devopsfetch
Run the installation script to install the `devopsfetch` tool and set up the systemd service. You can choose to install interactively or automatically with the `-y` flag.

**Interactive Installation**
```sh
./devopsfetch.sh
```
**Automatic Installation**
```sh
./devopsfetch.sh -y
```

## Usage
**Display All Active Ports and Services**

```sh
devopsfetch -p
```
To get detailed information about a specific port:

```sh
devopsfetch -p 80
```

**List All Docker Images and Containers**
```sh
devopsfetch -d
```
To get detailed information about a specific container:

```sh
devopsfetch -d container_name
```

**Display All Nginx Domains and Their Ports**

```sh
devopsfetch -n
```
To get detailed configuration information for a specific domain:

```sh
devopsfetch -n domain_name
```
**List All Users and Their Last Login Times**
```sh
devopsfetch -u
```
To get detailed information about a specific user:

```sh
devopsfetch -u username
```
**Display Activities Within a Specified Time Range**
```sh
devopsfetch -t "2024-07-23"
```
You can also display information by piping the output to less by adding terminal commands like | less or |more at the end of the command. This will allow you to scroll up and down using the arrow keys or j and k and see the descriptive column headings.

```sh
devopsfetch -t 2024-07-18 2024-07-22 | less
```

**Display Help**
To display usage instructions:

```sh
devopsfetch -h
```
**Logs and Monitoring**
The devopsfetch tool is configured to run as a systemd service for continuous monitoring. You can view the service logs using journalctl:

```sh
journalctl -u devopsfetch.service
```
