module vibe.rcon.client;

import std.regex;
import std.array;
import std.string;
import std.exception;

import vibe.core.net;

import vibe.rcon.protocol;

final class RCONClient {
    @safe:

    private {
        int rollingId = 0;
        TCPConnection connection;
    }

    this(string host, ushort port) {
        this(connectTCP(host, port));
    }

    this(TCPConnection connection) {
        this.connection = connection;
    }

    RCONPacket receive() {
        return RCONPacket.read(connection);
    }

    int send(string message) {
        return send(RCONPacket.Type.EXEC_COMMAND, message);
    }

    int send(RCONPacket.Type type, string message) {
        auto id = nextId;
        RCONPacket(id, type, message).write(connection);
        return id;
    }

    void send(RCONPacket packet) {
        packet.write(connection);
    }

    bool authenticate(string password) {
        auto authID = send(RCONPacket.Type.AUTH, password);

        // Source always sends an empty response before acknowledging success/failure
        auto empty = receive();
        enforce(empty.type == RCONPacket.Type.RESPONSE_VALUE);
        enforce(empty.message == "");

        auto authResponse = receive();
        enforce(authResponse.type == RCONPacket.Type.AUTH_RESPONSE);

        return authResponse.id == authID;
    }

    string exec(string command) {
        // This implements a trick that works for any command for handling multi-packet responses.
        // First send the command packet, then a response packet.
        // SRCDS responds with 0x000100 to the 2nd packet, after the first is complete.
        auto commandId = send(RCONPacket.Type.EXEC_COMMAND, command);
        auto endPacketId = send(RCONPacket.Type.RESPONSE_VALUE, null);

        auto result = appender!string;

        while (true) {
            auto packet = receive();

            if (packet.id == commandId) {
                enforce(packet.type == RCONPacket.Type.RESPONSE_VALUE);

                result ~= packet.message;
            } else if (packet.id == endPacketId && packet.type == RCONPacket.Type.RESPONSE_VALUE) {
                if (packet.message == "\x00\x01\x00") break;

                enforce(packet.message == "");
            } else {
                throw new Exception("");
            }
        }

        return result.data;
    }

    string readConVar(string convar) {
        // Console variables are responded to with something like the following:
        // "sv_password" = "xOKK5DKotcM6YSY6" ( def. "" )
        // notify
        // - Server password for entry into multiplayer games
        //
        // We can parse the actual value out of that.

        auto response = exec(convar);
        auto prefix = "\"%s\" = \"".format(convar);
        enforce(response.startsWith(prefix), "Invalid convar format");

        response = response[prefix.length..$];
        response = replaceFirst(response, regex("\" \\( def\\. \".*\" \\)[\n\r].*$", "s"), "");
        return response;
    }

    private @property auto nextId() {
        rollingId += 1;
        return rollingId;
    }
}
