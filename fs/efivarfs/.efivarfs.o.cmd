cmd_fs/efivarfs/efivarfs.o := ld.lld -EL  -maarch64elf -z norelro -z noexecstack   -r -o fs/efivarfs/efivarfs.o fs/efivarfs/inode.o fs/efivarfs/file.o fs/efivarfs/super.o
