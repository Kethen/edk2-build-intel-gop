# edk2-build-intel-gop

A build script for building edk2 along with intel-gop using https://github.com/Kethen/edk2

modified from https://projectacrn.github.io/latest/_static/downloads/build_acrn_ovmf.sh

secure boot building steps, ovmf-vars-generator and RedHatSecureBootPkKek1.pem obtained from https://src.fedoraproject.org/rpms/edk2

requires podman

### usage:
```
git clone https://github.com/Kethen/edk2-build-intel-gop
cd edk2-build-intel-gop
bash build_ovmf.sh -v
build_ovmf.sh [-v ver] [-i] [-s] [-h]
  -b branch/tag: checkout branch/tag instead of leaving it as default
  -i:     Delete the existing docker image  and re-create it
  -s:     Delete the existing edk2 source code and re-download it
  -S:     Build vanilla secure boot ovmf instead of intel gop
  -h:     Show this help
```

### building without secure boot:
```
mkdir gop
cp <intel gop driver efi> gop/IntelGopDriver.efi
cp <intel gop vbt> gop/Vbt.bin
bash build_ovmf.sh
```

### building with secure boot:
```
mkdir gop
cp <intel gop driver efi> gop/IntelGopDriver.efi
cp <intel gop vbt> gop/Vbt.bin
bash build_ovmf.sh -S
```

### built files

built files can be found in `edk2/Build/OvmfX64/DEBUG_GCC5/FV/`, `OVMF_CODE.fd` and `OVMF_VAR.fd` for non-secure boot builds

for secure boot builds, `OVMF_CODE.fd` and `OVMF_VAR.fd` can be found in `edk2/Build/Ovmf3264/DEBUG_GCC5/FV/`, with an additional `OVMF_VARS.enrolled.fd` with pre-enrolled redhat keys

### notes about secure boot builds along with intel-gop:

- secure boot builds only support machine type q35
- while it's rumored that one can get uefi video with igd+q35 on some devices, I've only had success with i440fx on my skylake and kabylake devices

### extracting IntelGopDriver.efi and Vbt.bin from your bios:

Vbt.bin and IntelGopDriver.efi can be extracted from your bios using https://github.com/LongSoft/UEFITool

for example, a kabylake lenovo insydeh20 bios 

IntelGopDriver.efi:

![image](https://user-images.githubusercontent.com/22017945/127104602-477dec76-0081-4b30-82b8-3d7e48196a48.png)

Vbt.bin

![image](https://user-images.githubusercontent.com/22017945/127104651-6466ab8d-adc6-4856-b1a7-90cb4cf96273.png)

