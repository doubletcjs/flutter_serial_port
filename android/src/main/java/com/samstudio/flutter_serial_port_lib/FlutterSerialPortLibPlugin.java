package com.samstudio.flutter_serial_port_lib;

import android.os.Handler;
import android.os.Looper;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

import android_serialport_api.SerialPort;
import android_serialport_api.SerialPortFinder;
import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * FlutterSerialPortLibPlugin
 */
public class FlutterSerialPortLibPlugin implements FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel channel;


    private static final String TAG = "FlutterSerialPortLibPlugin";
    private SerialPortFinder mSerialPortFinder = new SerialPortFinder();
    private EventChannel.EventSink mEventSink;
    private Handler mHandler = new Handler(Looper.getMainLooper());

    private Map<String, SerialPort> ports = new HashMap<>();
    private Map<String, ReadThread> readThreads = new HashMap<>();

    @Override
    public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "com.samstudio.flutter_serial_port_lib");
        channel.setMethodCallHandler(this);

        final EventChannel eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "com.samstudio.flutter_serial_port_lib/event");
        eventChannel.setStreamHandler((EventChannel.StreamHandler) this);
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        String devicePath = call.argument("devicePath");

        switch (call.method) {
            case "getPlatformVersion":
                result.success("Android " + android.os.Build.VERSION.RELEASE);
                break;
            case "open":
                if (ports.containsKey(devicePath) == false) {
                    final int baudRate = call.argument("baudRate");
                    final int parity = call.argument("parity");
                    final int dataBits = call.argument("dataBits");
                    final int stopBit = call.argument("stopBit");
                    Log.d(TAG, "Open " + devicePath + ", baudRate: " + baudRate + ", parity: " + parity + ", dataBits: " + dataBits + ", stopBit: " + stopBit);
                    Boolean openResult = openDevice(devicePath, baudRate, parity, dataBits, stopBit);
                    result.success(openResult);
                } else {
                    result.success(true);
                }
                break;
            case "close":
                Boolean closeResult = closeDevice(devicePath);
                result.success(closeResult);
                break;
            case "write":
                Boolean writeResult = writeData(devicePath, (byte[]) call.argument("data"));
                result.success(writeResult);
                break;
            case "getAllDevices":
                ArrayList<String> devices = getAllDevices();
                result.success(devices);
                break;
            case "getAllDevicesPath":
                ArrayList<String> devicesPath = getAllDevicesPath();
                result.success(devicesPath);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        Iterator<String> iterator = ports.keySet().iterator();
        while (iterator.hasNext()) {
            String port = iterator.next();

            boolean close = closeDevice(port);
            Log.e(TAG, "closeDevice: " + port + " close: " + close);
        }

        channel.setMethodCallHandler(null);
    }

    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {
        mEventSink = eventSink;
    }

    @Override
    public void onCancel(Object o) {
        mEventSink = null;
    }

    private ArrayList<String> getAllDevices() {
        ArrayList<String> devices = new ArrayList<String>(Arrays.asList(mSerialPortFinder.getAllDevices()));
        return devices;
    }

    private ArrayList<String> getAllDevicesPath() {
        ArrayList<String> devicesPath = new ArrayList<String>(Arrays.asList(mSerialPortFinder.getAllDevicesPath()));
        return devicesPath;
    }

    private class ReadThread extends Thread {
        private String devicePath;

        @Override
        public void run() {
            super.run();

            while (!isInterrupted()) {
                int size;
                try {
                    SerialPort mSerialPort = ports.get(devicePath);
                    InputStream mInputStream = mSerialPort.getInputStream();
                    if (mInputStream == null)
                        return;
                    byte[] buffer = new byte[1024];
                    size = mInputStream.read(buffer);
                    if (size > 0) {
                        onDataReceived(devicePath, buffer, size);
                    } 
                } catch (IOException e) {
                    e.printStackTrace();
                    android.util.Log.w("SerialPort", "ReadThread IOException:"+e.toString());
                    return;
                }
            }
        }
    }

    private Boolean openDevice(String devicePath, int baudRate, int parity, int dataBits, int stopBit) {
        /* Check parameters */

        if ((devicePath.length() == 0) || (baudRate == -1)) {
            return false;
        }

        /* Open the serial port */
        try {
            SerialPort mSerialPort = new SerialPort(new File(devicePath), baudRate, parity, dataBits, stopBit);
            if (mSerialPort.isOpen) {
                ports.put(devicePath, mSerialPort);

                ReadThread mReadThread = new ReadThread();
                mReadThread.devicePath = devicePath;
                mReadThread.start();

                readThreads.put(devicePath, mReadThread);

                return mSerialPort.isOpen;
            } else {
                return false;
            }
        } catch (Exception e) {
            Log.e(TAG, e.toString());
            return false;
        }
    }

    private Boolean closeDevice(String devicePath) {
        if ((devicePath.length() == 0)) {
            return false;
        }

        try {
            SerialPort mSerialPort = ports.get(devicePath);
            if (mSerialPort != null) {
                InputStream mInputStream = mSerialPort.getInputStream();
                if (null != mInputStream) {
                    mInputStream.close();
                }

                OutputStream mOutputStream = mSerialPort.getOutputStream();
                if (null != mOutputStream) {
                    mOutputStream.close();
                }

                if (mSerialPort.isOpen) { 
                    mSerialPort.close();
                }

                ports.remove(devicePath);
            }

            ReadThread mReadThread = readThreads.get(devicePath);
            if (null != mReadThread) {
                if (mReadThread.isInterrupted() == false) {
                    mReadThread.interrupt();
                }

                readThreads.remove(devicePath);
           }

            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    private Boolean writeData(String devicePath, byte[] data) {
        try {
            SerialPort mSerialPort = ports.get(devicePath);
            if (null == mSerialPort) return false;
            OutputStream mOutputStream = mSerialPort.getOutputStream();
            if (null == mOutputStream) return false;
            mOutputStream.write(data);
            // mOutputStream.write('\n');
            return true;
        } catch (IOException e) {
            Log.e(TAG, e.toString());
            return false;
        }
    }

    protected void onDataReceived(String devicePath, final byte[] buffer, final int size) {
        if (mEventSink != null) {
            mHandler.post(new Runnable() {
                @Override
                public void run() {
                    Map<String, Object> data = new HashMap<>();
                    data.put("port", devicePath);
                    data.put("event", Arrays.copyOfRange(buffer, 0, size));
                    data.put("size", size);
                    mEventSink.success(data);
                }
            });
        }
    }
}
