package com.callvault.prototype;

import android.os.ParcelFileDescriptor;

interface IShizukuRecorder {
    String ping();
    String startRecording(in ParcelFileDescriptor pfd);
    String stopRecording();
    boolean isRecording();
}
