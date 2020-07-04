#!/usr/bin/env zsh
# Copyright (c) 2019 Dyne.org Foundation
# arm-sdk is written and maintained by Ivan J. <parazyd@dyne.org>
#
# This file is part of arm-sdk
#
# This source code is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this source code. If not, see <http://www.gnu.org/licenses/>.

device_name="librem5-devkit"

gitbranch="imx8-current-librem5"
gitkernel="https://source.puri.sm/Librem5/linux-next.git"

uboot_defconfig="librem5_devkit"
uboot_branch="librem5"
uboot_git="https://source.puri.sm/Librem5/uboot-imx.git"

atf_platform="imx8mq"
atf_branch="librem5"
atf_git="https://source.puri.sm/Librem5/arm-trusted-firmware.git"

FK_MACHINE="Purism Librem 5 devkit"

source "$R/boards/librem5-common.sh"
