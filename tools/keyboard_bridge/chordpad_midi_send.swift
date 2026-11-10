import CoreMIDI
import Foundation
import Darwin

// Invoked by a Karabiner-Elements complex_modifications shell_command on
// key_down/key_up for r/t/y/u/f/g/h/j. Talks to chordpad_bridge_daemon over
// a local socket (fast, no per-event CoreMIDI setup -- see the daemon's
// source for why that matters: avoiding a stuck-note race under fast
// keypresses). Falls back to sending MIDI directly if the daemon isn't
// running, so the bridge still works (just without the daemon's ordering
// guarantee) if you forget to start it.
//
// Usage: chordpad_midi_send <on|off> <note 0-127> [velocity 0-127]

let socketPath = "/tmp/chordpad_keyboard_bridge.sock"
let portName = "ChordPad Keyboard"

func fail(_ message: String) -> Never {
	FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
	exit(1)
}

let args = CommandLine.arguments
guard args.count >= 3, args[1] == "on" || args[1] == "off", let note = UInt8(args[2]), note <= 127 else {
	fail("usage: chordpad_midi_send <on|off> <note 0-127> [velocity 0-127]")
}
let isNoteOn = args[1] == "on"
var velocity: UInt8 = isNoteOn ? 100 : 0
if args.count >= 4 {
	guard let v = UInt8(args[3]), v <= 127 else {
		fail("velocity must be 0-127")
	}
	velocity = v
}

func trySendViaDaemon() -> Bool {
	let fd = socket(AF_UNIX, SOCK_STREAM, 0)
	guard fd >= 0 else { return false }
	defer { close(fd) }

	var addr = sockaddr_un()
	addr.sun_family = sa_family_t(AF_UNIX)
	let pathBytes = Array(socketPath.utf8)
	withUnsafeMutableBytes(of: &addr.sun_path) { rawPtr in
		let buf = rawPtr.bindMemory(to: Int8.self)
		for (i, byte) in pathBytes.enumerated() {
			buf[i] = Int8(bitPattern: byte)
		}
		buf[pathBytes.count] = 0
	}
	let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
	let connectResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
		ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
			connect(fd, sockPtr, addrSize)
		}
	}
	guard connectResult == 0 else { return false }

	let message = "\(args[1]) \(note) \(velocity)\n"
	let written = message.withCString { write(fd, $0, strlen($0)) }
	return written > 0
}

func sendDirectFallback() {
	var client = MIDIClientRef()
	var checkStatus = MIDIClientCreate("ChordPadKeyboardBridge" as CFString, nil, nil, &client)
	guard checkStatus == noErr else {
		fail("MIDIClientCreate failed (OSStatus \(checkStatus))")
	}

	var outPort = MIDIPortRef()
	checkStatus = MIDIOutputPortCreate(client, "ChordPadKeyboardBridgeOut" as CFString, &outPort)
	guard checkStatus == noErr else {
		fail("MIDIOutputPortCreate failed (OSStatus \(checkStatus))")
	}

	var destination: MIDIEndpointRef?
	let destinationCount = MIDIGetNumberOfDestinations()
	for i in 0..<destinationCount {
		let candidate = MIDIGetDestination(i)
		var cfName: Unmanaged<CFString>?
		MIDIObjectGetStringProperty(candidate, kMIDIPropertyName, &cfName)
		if let name = cfName?.takeRetainedValue() as String?, name == portName {
			destination = candidate
			break
		}
	}
	guard let destination else {
		fail("daemon not running and MIDI destination \"\(portName)\" not found -- start tools/keyboard_bridge/chordpad_bridge_daemon, or enable IAC Driver in Audio MIDI Setup.")
	}

	let statusByte: UInt8 = (isNoteOn ? 0x90 : 0x80)
	var bytes: [UInt8] = [statusByte, note, velocity]
	var packetList = MIDIPacketList()
	let packetPtr = withUnsafeMutablePointer(to: &packetList) { MIDIPacketListInit($0) }
	_ = MIDIPacketListAdd(&packetList, 1024, packetPtr, 0, bytes.count, &bytes)

	checkStatus = MIDISend(outPort, destination, &packetList)
	guard checkStatus == noErr else {
		fail("MIDISend failed (OSStatus \(checkStatus))")
	}
}

if !trySendViaDaemon() {
	sendDirectFallback()
}
