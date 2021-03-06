
cdef class Packet(object):
    
    """A packet of encoded data within a :class:`~av.format.Stream`.

    This may, or may not include a complete object within a stream.
    :meth:`decode` must be called to extract encoded data.

    """
    def __init__(self):
        lib.av_init_packet(&self.struct)

    def __dealloc__(self):
        lib.av_free_packet(&self.struct)
    
    def __repr__(self):
        return '<%s.%s of %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.stream,
            id(self),
        )
    
    def decode(self):
        """Decode the data in this packet.

       yields frame.
       
       Note.
       Some codecs will cause frames to be buffered up in the decoding process. If Packets Data
       is NULL and size is 0 the packet will try and retrieve those frames. Context.demux will 
       yeild a NULL Packet as its last packet.
        """

        if not self.struct.data:
            while True:
                frame = self.stream.decode(self)
                if frame:
                    yield frame
                else:
                    break
        else:
            frame = self.stream.decode(self)
            if frame:
                yield frame
                
    property pts:
        def __get__(self): return self.struct.pts
    property dts:
        def __get__(self): return self.struct.dts
    property size:
        def __get__(self): return self.struct.size
    property duration:
        def __get__(self): return self.struct.duration

