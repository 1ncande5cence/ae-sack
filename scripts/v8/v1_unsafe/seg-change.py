import lief

binary = lief.parse("./d8.fuzz.pre")
for segment in binary.segments:
    print(segment)
        # Fix: cast back to SEGMENT_FLAGS enum after OR
    new_flags = lief.ELF.SEGMENT_FLAGS(segment.flags | lief.ELF.SEGMENT_FLAGS.W)
    segment.flags = new_flags

binary.write("d8.fuzz")