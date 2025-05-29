/*
 * Copyright 2009 Cedric Priscal
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package android_serialport_api;

import android.util.Log;

import java.io.File;
import java.io.FileDescriptor;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

public class SerialPort {

    private static final String TAG = "SerialPort";
    public boolean isOpen = false;

    static {
        try {
            System.loadLibrary("serial_port");
        } catch (UnsatisfiedLinkError | Exception e) {
            e.printStackTrace();
            Log.e("SerialPort", "System.loadLibrary error:" + e.toString());
        }
    }

    /*
     * Do not remove or rename the field mFd: it is used by native method close();
     */
    private FileInputStream mFileInputStream;
    private FileOutputStream mFileOutputStream;

    public SerialPort(File device, int baudRate, int parity, int dataBits, int stopBit) throws SecurityException {

        /* Check access permission */
        if (!device.canRead() || !device.canWrite()) {
            try {
                /* Missing read/write permission, trying to chmod the file */
                Log.w("SerialPort", "trying to set access 777 for device");
                Process su = Runtime.getRuntime().exec(new String[]{"/system/xbin/su", "root", "chmod 777 " + device.getAbsolutePath()});
                if (su.waitFor() != 0 || !device.canRead() || !device.canWrite()) {
                    Log.w("SerialPort", "failed to set access"); 
                } else {
                    Log.w("SerialPort", "access successful set");
                }
            } catch (Exception e) {
                Log.e("SerialPort", "FileDescriptor open error:" + e.toString());
            }
        }

        try {
            FileDescriptor mFd = open(device.getAbsolutePath(), baudRate, parity, dataBits, stopBit, 0);
            if (mFd == null) {
                Log.e("SerialPort", "native open returns null");
                isOpen = false;
            } else {
                Log.w("SerialPort", "allocated file descriptor for serial port");
                this.mFileInputStream = new FileInputStream(mFd);
                this.mFileOutputStream = new FileOutputStream(mFd);
                isOpen = true;
            }
        } catch (UnsatisfiedLinkError | Exception e) {
            Log.e("SerialPort", "FileDescriptor open error:" + e.toString());
            isOpen = false;
        }
    }

    // Getters and setters
    public InputStream getInputStream() {
        return mFileInputStream;
    }

    public OutputStream getOutputStream() { return mFileOutputStream; }

    // JNI

    /**
     * 打开串口
     *
     * @param path     串口设备文件
     * @param baudRate 波特率
     * @param parity   奇偶校验，0 None（默认）； 1 Odd； 2 Even
     * @param dataBits 数据位，5 ~ 8  （默认8）
     * @param stopBit  停止位，1 或 2  （默认 1）
     * @param flags    标记 0（默认）
     * @throws SecurityException
     */

    private native static FileDescriptor open(String path, int baudRate, int parity, int dataBits, int stopBit, int flags);

    public native void close();
}
