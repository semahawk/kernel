.PHONY: all bootloader kernel tools run disk_image clean distclean

DISK_IMAGE = leoman.iso

SUBDIRS = boot kernel tools

all: bootloader $(DISK_IMAGE)

bootloader:
	cd boot; $(MAKE)

kernel:
	cd kernel; $(MAKE)

run: $(DISK_IMAGE)
	qemu-system-i386 -cdrom $(DISK_IMAGE) -monitor stdio

tools:
	cd tools; $(MAKE)

$(DISK_IMAGE): bootloader kernel
	mkdir -p iso_root/boot
# install the files into the image
	cp kernel/kernel iso_root/boot
	cp boot/boot.bin iso_root/boot
# create the ISO
	mkisofs -R -J -c boot/boot.cat -b boot/boot.bin -no-emul-boot -boot-load-size 4 -o $(DISK_IMAGE) iso_root
# install the bootloader
	dd conv=notrunc if=boot/boot.bin of=$(DISK_IMAGE) bs=512 count=1

clean:
	rm -f *.iso
	
	for DIR in $(SUBDIRS); do \
		$(MAKE) -C $$DIR clean; \
	done

distclean: clean
	for DIR in $(SUBDIRS); do \
		$(MAKE) -C $$DIR distclean; \
	done

