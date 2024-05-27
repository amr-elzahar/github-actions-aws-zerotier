#!/bin/bash

apt-get update
curl -s https://install.zerotier.com | sudo bash # To install ZeroTier Client
sudo zerotier-cli join 