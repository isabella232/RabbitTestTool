package com.jackvanlightly.rabbittesttool.clients.publishers;

import com.jackvanlightly.rabbittesttool.clients.MessagePayload;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;

public class MessageGenerator {
    private ByteBuffer messageBuf;
    private int messageSize;
    private byte[] uninstrumented;

    public synchronized void setBaseMessageSize(int bytes) {
        if(bytes <= MessagePayload.MinimumMessageSize)
            bytes = MessagePayload.MinimumMessageSize;

        messageSize = bytes;
        messageBuf = ByteBuffer.allocate(bytes);

        uninstrumented = new byte[messageSize];
        System.arraycopy(messageBuf.array(), 0, uninstrumented, 0, messageSize);
    }

    public byte[] getUninstrumentedMessageBytes() {
        return uninstrumented;
//        byte[] bytes = new byte[messageSize];
//        System.arraycopy(messageBuf.array(), 0, bytes, 0, messageSize);
//        return bytes;
    }

    public synchronized byte[] getMessageBytes(MessagePayload mp) throws IOException {
        messageBuf.position(0);
        messageBuf.putInt(mp.getStream());
        messageBuf.putLong(mp.getSequenceNumber());
        messageBuf.putLong(mp.getTimestamp());

        byte[] msgBytes = new byte[messageSize];
        System.arraycopy(messageBuf.array(), 0, msgBytes, 0, messageSize);
        return msgBytes;
    }

    public static MessagePayload toMessagePayload(byte[] body) throws IOException {
        ByteBuffer bbuffer = ByteBuffer.wrap(body);
        Integer stream = bbuffer.getInt();
        Long seqNumber = bbuffer.getLong();
        long timestamp = bbuffer.getLong();

//        DataInputStream data = new DataInputStream(new ByteArrayInputStream(body));
//        Integer stream = data.readInt();
//        Long seqNumber = data.readLong();
//        long timestamp = data.readLong();

        MessagePayload mp = new MessagePayload();
        mp.setStream(stream);
        mp.setSequenceNumber(seqNumber);
        mp.setTimestamp(timestamp);

        return mp;
    }
}
