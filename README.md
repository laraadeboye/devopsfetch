# Devopsfetch

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
- Root privileges

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
sudo ./devopsfetch-install.sh
```
**Automatic Installation**
```sh
sudo ./devopsfetch-install.sh -y
```

## Usage
**Display All Active Ports and Services**

```sh
sudo devopsfetch -p
```
To get detailed information about a specific port:

```sh
sudo devopsfetch -p 80
```

**List All Docker Images and Containers**
```sh
sudo devopsfetch -d
```
To get detailed information about a specific container:

```sh
sudo devopsfetch -d container_name
```

**Display All Nginx Domains and Their Ports**

```sh
sudo devopsfetch -n
```
To get detailed configuration information for a specific domain:

```sh
sudo devopsfetch -n domain_name
```
**List All Users and Their Last Login Times**
```sh
sudo devopsfetch -u
```
To get detailed information about a specific user:

```sh
sudo devopsfetch -u username
```
**Display Activities Within a Specified Time Range**
```sh
sudo devopsfetch -t "2024-07-01"
```
**Display Help**
To display usage instructions:

```sh
sudo devopsfetch -h
```
**Logs and Monitoring**
The devopsfetch tool is configured to run as a systemd service for continuous monitoring. You can view the service logs using journalctl:

```sh
sudo journalctl -u devopsfetch.service
```
