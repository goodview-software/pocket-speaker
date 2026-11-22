package fr.goodview.overlay;

/** État partagé entre le plugin (appelé par GDScript) et le service (bulle). */
final class OverlayState {
	static volatile boolean enabled = false;
	static volatile boolean ok = false;
	static volatile String text = "";
	static volatile boolean buttons = false;
	static volatile boolean sound = true;
	static volatile boolean mic = false;
	static volatile String action = "";

	private OverlayState() {}
}
