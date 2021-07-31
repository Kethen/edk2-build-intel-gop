#!/bin/bash
# Copyright (C) 2021 Intel Corporation.
# SPDX-License-Identifier: BSD-3-Clause
#
# PREREQUISITES:
# 1) Get your specific "IntelGopDriver.efi" and "Vbt.bin"
#    from your BIOS vender
# 2) Install podman
# 3) If you are working behind proxy, create a file named
#    "proxy.conf" in ${your_working_directory} with
#    configurations like below:
#    Acquire::http::Proxy "http://x.y.z:port1";
#    Acquire::https::Proxy "https://x.y.z:port2";
#    Acquire::ftp::Proxy "ftp://x.y.z:port3";
#
# HOWTO:
# 1) mkdir ${your_working_directory}
# 2) cd ${your_working_directory}
# 2) mkdir gop
# 3) cp /path/to/IntelGopDriver.efi /path/to/Vbt.bin gop
# 4) cp /path/to/build_ovmf.sh ${your_working_directory}
# 5) ./build_ovmf.sh
#
# OUTPUT: ${your_working_directory}/edk2/Build/OvmfX64/DEBUG_GCC5/FV/OVMF.fd
#
# For more information, ./build_ovmf.sh -h
#

gop_bin_dir="./gop"
podman_image_name="ubuntu:ovmf.18.04"
proxy_conf="proxy.conf"
branch=""
secureboot=""

if [ ! -x "$(command -v podman)" ]; then
    echo "Install Docker first:"
    echo "If you are using Ubuntu, you can refer to: https://docs.docker.com/engine/install/ubuntu/"
    exit
fi

if [ ! -d "${gop_bin_dir}" ]; then
    mkdir ${gop_bin_dir}
    echo "Copy IntelGopDriver.efi and Vbt.bin to ${gop_bin_dir}"
    exit
fi

if [ ! -f "${gop_bin_dir}/IntelGopDriver.efi" ]; then
    echo "Copy IntelGopDriver.efi to ${gop_bin_dir}"
    exit
fi

if [ ! -f "${gop_bin_dir}/Vbt.bin" ]; then
    echo "Copy Vbt.bin to ${gop_bin_dir}"
    exit
fi

if [ ! -f "${proxy_conf}" ]; then
    touch "${proxy_conf}"
fi

usage()
{
    echo "$0 [-v ver] [-i] [-s] [-h]"
    echo "  -b branch/tag: checkout branch/tag instead of leaving it as default"
    echo "  -i:     Delete the existing docker image ${docker_image_name} and re-create it"
    echo "  -s:     Delete the existing edk2 source code and re-download/re-patch it"
    echo "  -S:     Build vanilla secure boot ovmf instead of intel gop"
    echo "  -h:     Show this help"
    exit
}

re_download=0
re_create_image=0

while getopts "hisb:S" opt
do
    case "${opt}" in
        h)
            usage
            ;;
        i)
            re_create_image=1
            ;;
        s)
            re_download=1
            ;;
        b)
            branch=${OPTARG}
            ;;
        S)
            secureboot=yes
            ;;
        ?)
            echo "${OPTARG}"
            ;;
    esac
done
shift $((OPTIND-1))

if [[ "${re_create_image}" -eq 1 ]]; then
    if [[ "$(podman images -q ${podman_image_name} 2> /dev/null)" != "" ]]; then
        echo "===================================================================="
        echo "Deleting the old Docker image ${podman_image_name}  ..."
        echo "===================================================================="
        podman image rm -f "${podman_image_name}"
    fi
fi

if [[ "${re_download}" -eq 1 ]]; then
    echo "===================================================================="
    echo "Deleting the old edk2 source code ..."
    echo "===================================================================="
    rm -rf edk2
fi

create_edk2_workspace()
{
    echo "===================================================================="
    echo "Downloading edk2 source code ..."
    echo "===================================================================="

    [ -d edk2 ] && rm -rf edk2

    git clone https://github.com/Kethen/edk2.git
    if [ $? -ne 0 ]; then
        echo "git clone edk2 failed"
        return 1
    fi

    cd edk2
    if [ -n "$branch" ]
    then
    	git checkout "$branch"
    fi
    git submodule update --init --recursive
    if [ $? -ne 0 ]; then
        echo "git submodule edk2 failed"
        return 1
    fi

    return 0
}

create_podman_image()
{
    echo "===================================================================="
    echo "Creating Docker image ..."
    echo "===================================================================="

    cat > Dockerfile.ovmf <<EOF
FROM ubuntu:18.04

WORKDIR /root/acrn

COPY ${proxy_conf} /etc/apt/apt.conf.d/proxy.conf
RUN apt update && apt install -y gcc-5 g++-5 make nano git python uuid-dev nasm iasl
RUN ln -s /usr/bin/gcc-5 /usr/bin/gcc; ln -s /usr/bin/gcc-5 /usr/bin/cc; ln -s /usr/bin/g++-5 /usr/bin/g++; ln -s /usr/bin/gcc-ar-5 /usr/bin/gcc-ar
EOF

    podman build -t "${podman_image_name}" -f Dockerfile.ovmf .
    rm Dockerfile.ovmf
}

if [[ "$(podman images -q ${podman_image_name} 2> /dev/null)" == "" ]]; then
    create_podman_image
fi

if [ ! -d edk2 ]; then
    create_edk2_workspace
    if [ $? -ne 0 ]; then
        echo "Download/patch edk2 failed"
        exit
    fi
else
    cd edk2
fi

cp -f ../${gop_bin_dir}/IntelGopDriver.efi OvmfPkg/IntelGop/IntelGopDriver.efi
cp -f ../${gop_bin_dir}/Vbt.bin OvmfPkg/Vbt/Vbt.bin

source edksetup.sh

sed -i 's:^ACTIVE_PLATFORM\s*=\s*\w*/\w*\.dsc*:ACTIVE_PLATFORM       = OvmfPkg/OvmfPkgX64.dsc:g' Conf/target.txt
sed -i 's:^TARGET_ARCH\s*=\s*\w*:TARGET_ARCH           = X64:g' Conf/target.txt
sed -i 's:^TOOL_CHAIN_TAG\s*=\s*\w*:TOOL_CHAIN_TAG        = GCC5:g' Conf/target.txt

cd ..

OVMF_FLAGS="-DDEBUG_ON_SERIAL_PORT=TRUE"
OVMF_FLAGS="$OVMF_FLAGS -DNETWORK_IP6_ENABLE -DNETWORK_HTTP_BOOT_ENABLE -DNETWORK_TLS_ENABLE"

SECURE_BOOT=""
if [ -n "$secureboot" ]
then
	OVMF_FLAGS="$OVMF_FLAGS -DFD_SIZE_4MB"
	SECURE_BOOT="-DSECURE_BOOT_ENABLE -DSMM_REQUIRE -DEXCLUDE_SHELL_FROM_FD"
	SECURE_BOOT="$SECURE_BOOT -DTPM_ENABLE"
	SECURE_BOOT="$SECURE_BOOT -a IA32 -a X64 -p OvmfPkg/OvmfPkgIa32X64.dsc"
else
	OVMF_FLAGS="$OVMF_FLAGS -DFD_SIZE_2MB"
fi

podman run \
    -ti \
    --rm \
    -w $PWD/edk2 \
    -v $PWD:$PWD \
    ${podman_image_name} \
    /bin/bash -c "source edksetup.sh && make -C BaseTools && build $OVMF_FLAGS $SECURE_BOOT"