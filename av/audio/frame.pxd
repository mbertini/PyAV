from libc.stdint cimport uint8_t, uint64_t, int64_t

cimport libav as lib

from av.frame cimport Frame
from av.audio.swrcontext cimport SwrContextProxy


cdef class AudioFrame(Frame):

    # This is the size of the Frame.ptr.data[0] buffer, not the _buffer below.
    cdef readonly int buffer_size
    cdef int _get_buffer_size(self)
    
    # For raw storage of the frame's data.
    cdef uint8_t **_buffer

    cdef int align
    cdef readonly int frame_index
    
    cdef SwrContextProxy swr_proxy


    cdef alloc_frame(self, int channels, lib.AVSampleFormat sample_fmt, int nb_samples)
    cdef fill_frame(self, int nb_samples)

    cpdef resample(self, bytes channel_layout, bytes sample_fmt, int sample_rate)
    
    # PEP 3118 buffer protocol.
    cdef Py_ssize_t _buffer_shape[3]
    cdef Py_ssize_t _buffer_strides[3]
    cdef Py_ssize_t _buffer_suboffsets[3]