module vibe.rcon.protocol;

import std.format;
import std.bitmanip;
import std.exception;

import vibe.core.net;
import vibe.core.stream;

struct RCONPacket {
    @safe:

    enum Type {
        AUTH = 3,
        AUTH_RESPONSE = 2,
        EXEC_COMMAND = 2,
        RESPONSE_VALUE = 0,
    }

    int id;
    Type type;
    string message;

    static RCONPacket read(S)(S stream) if (isInputStream!S) {
        ubyte[4] sizeBuffer;
        stream.read(sizeBuffer);
        auto size = littleEndianToNative!int(sizeBuffer);
        enforce(size >= 10 && size <= 4096, "Invalid packet size");

        auto buffer = new ubyte[size];
        stream.read(buffer);
        return RCONPacket.fromBuffer(buffer);
    }

    static RCONPacket fromBuffer(ubyte[] data) @trusted {
        auto id = data.read!(int, Endian.littleEndian);
        auto type = data.read!(Type, Endian.littleEndian);
        string message = null;

        // Some messages are plain empty, including no \0 at the end
        if (data.length > 2) {
            // TODO: encode?
            message = cast(string)data[0..data.length - 3];
        }

        return RCONPacket(id, type, message);
    }

    unittest {
        auto data =
            nativeToLittleEndian(5) ~
            nativeToLittleEndian(3) ~
            cast(ubyte[])[0x66, 0x6f, 0x6f, 0x00, 0x00, 0x00];

        auto packet = RCONPacket.fromBuffer(data);
        assert(packet.id == 5);
        assert(packet.type == 3);
        assert(packet.message == "foo");
    }

    this(int id, Type type, string message) {
        this.id = id;
        this.type = type;
        this.message = message;
    }

    @property int size() {
        // Null character + header size
        return cast(int)(message.length + 1 + 10);
    }

    ubyte[] header() @trusted {
        auto data = new ubyte[12];
        data.write!(int, Endian.littleEndian)(size, 0);
        data.write!(int, Endian.littleEndian)(id, 4);
        data.write!(int, Endian.littleEndian)(type, 8);
        return data;
    }

    ubyte[] toBuffer() @trusted {
        auto data = new ubyte[size + 4];
        size_t offset = 0;

        data[offset..offset + 12] = header();
        offset += 12;

        // TODO: decode?
        data[offset..offset + message.length] = cast(ubyte[])message;
        offset += message.length;

        data[offset..offset + 3] = [0x00, 0x00, 0x00];
        return data;
    }

    unittest {
        auto packet = RCONPacket(5, Type.AUTH, "foo");

        assert(packet.toBuffer() ==
            nativeToLittleEndian(14) ~
            nativeToLittleEndian(5) ~
            nativeToLittleEndian(3) ~
            cast(ubyte[])[0x66, 0x6f, 0x6f, 0x00, 0x00, 0x00]);
    }

    void write(O)(O stream) if (isOutputStream!O) {
        stream.write(toBuffer());
    }

    string toString() {
        return "RCON(%s, %s, %s)".format(id, type, message);
    }
}
