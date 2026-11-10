import CoreMIDI
import Foundation
import Darwin

// Long-lived process that owns a single CoreMIDI connection to the
// "ChordPad Keyboard" IAC port and relays Note On/Off messages received over
// a local Unix socket. chordpad_midi_send (spawned fresh by Karabiner on
// every key event) talks to this daemon instead of doing CoreMIDI setup
// itself.
//
// This exists specifically to fix a stuck-note race: MIDIClientCreate/
// MIDIOutputPortCreate negotiate with the system's CoreMIDI server over IPC,
// which takes a variable amount of time (worse under load, e.g. several keys
// pressed together spawning several processes at once). When a key's "off"
// process was spawned after its "on" process but happened to finish that
// setup faster, the off MIDI message could reach ChordPad before the on
// message -- ChordPad ignores an off for a pad that isn't active yet, then
// the late on arrives with no further off ever coming, so the note never
// stops sounding. Doing the CoreMIDI setup exactly once here, up front, and
// only ever doing a cheap socket read per event afterward, shrinks that race
// window from "tens of milliseconds, worse under load" to "sub-millisecond,
// bounded by local process scheduling" -- well under realistic keypress
// timing.
//
// Single-threaded accept loop: each connection is fully read and processed
// before the next is accepted, so if two clients do race at the socket
// layer, the daemon still handles them one at a time in true arrival order
// rather than adding its own reordering on top.

let socketPath = "/tmp/chordpad_keyboard_bridge.sock"
let portName = "ChordPad Keyboard"

func log(_ message: String) {
	FileHandle.standardError.write(("[chordpad_bridge_daemon] " + message + "\n").data(using: .utf8)!)
}

var client = MIDIClientRef()
var status = MIDIClientCreate("ChordPadKeyboardBridgeDaemon" as CFString, nil, nil, &client)
guard status == noErr else {
	log("MIDIClientCreate failed (OSStatus \(status))")
	exit(1)
}

var outPort = MIDIPortRef()
status = MIDIOutputPortCreate(client, "ChordPadKeyboardBridgeDaemonOut" as CFString, &outPort)
guard status == noErr else {
	log("MIDIOutputPortCreate failed (OSStatus \(status))")
	exit(1)
}

func findDestination() -> MIDIEndpointRef? {
	let count = MIDIGetNumberOfDestinations()
	for i in 0..<count {
		let candidate = MIDIGetDestination(i)
		var cfName: Unmanaged<CFString>?
		MIDIObjectGetStringProperty(candidate, kMIDIPropertyName, &cfName)
		if let name = cfName?.takeRetainedValue() as String?, name == portName {
			return candidate
		}
	}
	return nil
}

func sendNote(statusByte: UInt8, note: UInt8, velocity: UInt8) {
	guard let destination = findDestination() else {
		log("destination \"\(portName)\" not found -- enable IAC Driver in Audio MIDI Setup and add a port named exactly \"\(portName)\".")
		return
	}
	var bytes: [UInt8] = [statusByte, note, velocity]
	var packetList = MIDIPacketList()
	let packetPtr = withUnsafeMutablePointer(to: &packetList) { MIDIPacketListInit($0) }
	_ = MIDIPacketListAdd(&packetList, 1024, packetPtr, 0, bytes.count, &bytes)
	let sendStatus = MIDISend(outPort, destination, &packetList)
	if sendStatus != noErr {
		log("MIDISend failed (OSStatus \(sendStatus))")
	}
}

func makeSocketAddress(_ path: String) -> sockaddr_un {
	var addr = sockaddr_un()
	addr.sun_family = sa_family_t(AF_UNIX)
	let pathBytes = Array(path.utf8)
	withUnsafeMutableBytes(of: &addr.sun_path) { rawPtr in
		let buf = rawPtr.bindMemory(to: Int8.self)
		for (i, byte) in pathBytes.enumerated() {
			buf[i] = Int8(bitPattern: byte)
		}
		buf[pathBytes.count] = 0
	}
	return addr
}

unlink(socketPath)
let serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
guard serverFD >= 0 else {
	log("socket() failed (errno \(errno))")
	exit(1)
}

var addr = makeSocketAddress(socketPath)
let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
let bindResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
	ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
		bind(serverFD, sockPtr, addrSize)
	}
}
guard bindResult == 0 else {
	log("bind() failed (errno \(errno))")
	exit(1)
}
chmod(socketPath, 0o600)
guard listen(serverFD, 32) == 0 else {
	log("listen() failed (errno \(errno))")
	exit(1)
}

log("listening on \(socketPath), forwarding to \"\(portName)\"")

while true {
	let clientFD = accept(serverFD, nil, nil)
	guard clientFD >= 0 else { continue }
	defer { close(clientFD) }

	var buffer = [UInt8](repeating: 0, count: 256)
	let n = read(clientFD, &buffer, buffer.count)
	guard n > 0 else { continue }
	let text = String(decoding: buffer[0..<n], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
	let parts = text.split(separator: " ")
	guard parts.count >= 2, parts[0] == "on" || parts[0] == "off", let note = UInt8(parts[1]) else {
		log("bad message: \(text)")
		continue
	}
	var velocity: UInt8 = parts[0] == "on" ? 100 : 0
	if parts.count >= 3, let v = UInt8(parts[2]) {
		velocity = v
	}
	log("\(Date().timeIntervalSince1970) \(parts[0]) \(note)")
	sendNote(statusByte: parts[0] == "on" ? 0x90 : 0x80, note: note, velocity: velocity)
}
