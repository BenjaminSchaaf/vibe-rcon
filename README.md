# vibe.rcon

This is an implementation of the source RCON protocol, used to communicate
remotely with game servers.

You can read about the source RCON protocol [on the developer wiki](https://developer.valvesoftware.com/wiki/Source_RCON_Protocol).

## Installing

You can install this package using [dub](https://code.dlang.org):

```sdl
dependency "vibe-rcon" version="~>1.0"
```

```json
"dependencies": {
    "vibe-rcon": "~>1.0",
}
```

## Usage

```d
import vibe.rcon;

auto client = new RCONClient("119.15.96.156", 27041);

// You can use standard source RCON authentication
bool success = client.authenticate("<rcon password>");

// You can send rcon commands
string response = client.exec("status");

// You can also easily retrieve console variables (convars)
string value = client.readConVar("sv_password");

// For more direct control you can directly send and receive RCON packets
client.send(RCONPacket(2, RCONPacket.Type.AUTH_RESPONSE, "hi"));
RCONPacket response = client.receive();

// Or you can let the client handle the packet ID for you
int id = client.send(RCONPacket.Type.AUTH_RESPONSE, "hi");
RCONPacket response = client.receive();
assert(response.id == id);
```

## License

This project is distributed under the MIT license.
