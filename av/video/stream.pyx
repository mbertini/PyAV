from libc.stdint cimport int64_t

from av.packet cimport Packet
from av.utils cimport err_check


cdef class VideoStream(Stream):
    
    def __init__(self, *args):
        super(VideoStream, self).__init__(*args)
        self.last_w = 0
        self.last_h = 0
        
        self.encoded_frame_count = 0
    
    def __dealloc__(self):
        # These are all NULL safe.
        lib.avcodec_free_frame(&self.raw_frame)
        
    cpdef decode(self, Packet packet):
        
        if not self.raw_frame:
            self.raw_frame = lib.avcodec_alloc_frame()
            lib.avcodec_get_frame_defaults(self.raw_frame)

        cdef int done = 0
        err_check(lib.avcodec_decode_video2(self.codec.ctx, self.raw_frame, &done, &packet.struct))
        if not done:
            return
        
        # Check if the frame size has change
        if not (self.last_w,self.last_h) == (self.codec.ctx.width,self.codec.ctx.height):
            
            self.last_w = self.codec.ctx.width
            self.last_h = self.codec.ctx.height
            
            # Recalculate buffer size
            self.buffer_size = lib.avpicture_get_size(
                self.codec.ctx.pix_fmt,
                self.codec.ctx.width,
                self.codec.ctx.height,
            )
            
            # Create a new SwsContextProxy
            self.sws_proxy = SwsContextProxy()

        cdef VideoFrame frame = VideoFrame()
        
        # Copy the pointers over.
        frame.buffer_size = self.buffer_size
        frame.ptr = self.raw_frame

        # Calculate best effort time stamp    
        frame.ptr.pts = lib.av_frame_get_best_effort_timestamp(frame.ptr)
        frame.time_base_ = self.ptr.time_base
        
        # Copy SwsContextProxy so frames share the same one
        frame.sws_proxy = self.sws_proxy
        
        # Null out our frame.
        self.raw_frame = NULL
        
        return frame
    
    cpdef encode(self, VideoFrame frame=None):
        """Encodes a frame of video, returns a packet if one is ready.
        The output packet does not necessarily contain data for the most recent frame, 
        as encoders can delay, split, and combine input frames internally as needed.
        If called with with no args it will flush out the encoder and return the buffered
        packets until there are none left, at which it will return None.
        """
        
        # setup formatContext for encoding
        self.weak_ctx().start_encoding()
        
        if not self.sws_proxy:
            self.sws_proxy = SwsContextProxy()
            
        cdef VideoFrame formated_frame
        cdef Packet packet
        cdef int got_output
        
        if frame:
            frame.sws_proxy = self.sws_proxy
            formated_frame = frame.reformat(self.codec.width,self.codec.height, self.codec.pix_fmt)

        else:
            # Flushing
            formated_frame = None

        packet = Packet()
        packet.struct.data = NULL #packet data will be allocated by the encoder
        packet.struct.size = 0
        
        if formated_frame:
            
            if formated_frame.ptr.pts != lib.AV_NOPTS_VALUE:
                formated_frame.ptr.pts = lib.av_rescale_q(formated_frame.ptr.pts, 
                                                          formated_frame.time_base_, #src 
                                                          self.codec.ctx.time_base) #dest
                                
            else:
                pts_step = 1/float(self.codec.frame_rate) * self.codec.ctx.time_base.den
                formated_frame.ptr.pts = <int64_t> (pts_step * self.encoded_frame_count)
                
            
            self.encoded_frame_count += 1
            ret = err_check(lib.avcodec_encode_video2(self.codec.ctx, &packet.struct, formated_frame.ptr, &got_output))
        else:
            # Flushing
            ret = err_check(lib.avcodec_encode_video2(self.codec.ctx, &packet.struct, NULL, &got_output))

        if got_output:
            
            # rescale the packet pts and dts, which are in codec time_base, to the streams time_base

            if packet.struct.pts != lib.AV_NOPTS_VALUE:
                packet.struct.pts = lib.av_rescale_q(packet.struct.pts, 
                                                         self.codec.ctx.time_base,
                                                         self.ptr.time_base)
            if packet.struct.dts != lib.AV_NOPTS_VALUE:
                packet.struct.dts = lib.av_rescale_q(packet.struct.dts, 
                                                     self.codec.ctx.time_base,
                                                     self.ptr.time_base)
            if self.codec.ctx.coded_frame.key_frame:
                packet.struct.flags |= lib.AV_PKT_FLAG_KEY
                
            packet.struct.stream_index = self.ptr.index
            packet.stream = self

            return packet

