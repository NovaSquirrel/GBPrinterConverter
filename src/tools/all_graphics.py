import glob, os

os.makedirs("assets", exist_ok=True)
outfile = open("assets/all_graphics.asm", "w")

file_count = 0
outfile.write('SECTION "File_Directory", ROM0\n')
outfile.write('FileDirectory::\n')
for f in glob.glob("src/assets/images/*.png"):
	b = os.path.basename(f)
	pre, ext = os.path.splitext(b)
	outfile.write('dw File_%s\n' % pre)
	outfile.write('db BANK(File_%s)\n' % pre)
	outfile.write('dw File_%s_End - File_%s\n' % (pre, pre))
	file_count += 1
outfile.write('dw $ffff\n')
outfile.write('FileCount:: db %d\n' % file_count)

for f in glob.glob("src/assets/images/*.png"):
	b = os.path.basename(f)
	pre, ext = os.path.splitext(b)
	outfile.write('SECTION "File_%s", ROMX\n' % pre)
	outfile.write('File_%s:\n' % pre)
	outfile.write('incbin "assets/images/%s.2bpp"\n' % pre)
	outfile.write('File_%s_End:\n' % pre)
outfile.close()

