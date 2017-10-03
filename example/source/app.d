import std.conv;
import std.stdio;
import std.exception;

import vibe.rcon;

void main(string[] args) {
    auto ip = args[1];
    auto port = args[2].to!ushort;
    auto password = args[3];

    auto client = new RCONClient(ip, port);

    enforce(client.authenticate(password));

    while (true) {
        auto line = readln();
        if (line is null) break;

        writeln(client.exec(line));
    }
}
