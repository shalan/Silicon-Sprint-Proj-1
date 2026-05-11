from cli import init, process_line

print("=" * 50)
print("  USB CDC Test Chip — Pico Debug Probe")
print("=" * 50)
print("Initializing...")
init()
print("Ready. Type 'help' for commands.\n")

while True:
    try:
        line = input("> ")
        process_line(line)
    except KeyboardInterrupt:
        print("^C")
    except Exception as e:
        print("Error: %s" % e)
