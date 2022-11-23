#!/bin/bash

wget https://github.com/restic/restic/releases/download/v0.14.0/restic_0.14.0_linux_amd64.bz2
bzip2 -d restic_0.14.0_linux_amd64.bz2
mv restic_0.14.0_linux_amd64 restic
chmod +x restic
