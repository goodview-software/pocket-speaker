package fr.goodview.overlay;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import androidx.annotation.NonNull;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/** Plugin Godot « PocketOverlay » : service de premier plan + bulle flottante quand l'app passe en arrière-plan. */
public class OverlayPlugin extends GodotPlugin {
	public OverlayPlugin(Godot godot) {
		super(godot);
	}

	@NonNull
	@Override
	public String getPluginName() {
		return "PocketOverlay";
	}

	@UsedByGodot
	public boolean has_permission() {
		return Settings.canDrawOverlays(getActivity());
	}

	/** Ouvre l'écran Android « Afficher par-dessus les autres applis » de cette app. */
	@UsedByGodot
	public void request_permission() {
		Activity a = getActivity();
		if (a == null) return;
		Intent i = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + a.getPackageName()));
		a.startActivity(i);
	}

	@UsedByGodot
	public void set_enabled(boolean on) {
		OverlayState.enabled = on;
	}

	/** ok : liaison active ; text : état court ; buttons : affiche les boutons son/micro. */
	@UsedByGodot
	public void set_state(boolean ok, String text, boolean buttons, boolean sound, boolean mic) {
		OverlayState.ok = ok;
		OverlayState.text = text;
		OverlayState.buttons = buttons;
		OverlayState.sound = sound;
		OverlayState.mic = mic;
		OverlayService.refresh();
	}

	/** « sound », « mic » ou "" : dernière action demandée depuis la bulle. */
	@UsedByGodot
	public String take_action() {
		String a = OverlayState.action;
		OverlayState.action = "";
		return a;
	}

	@Override
	public void onMainPause() {
		Activity a = getActivity();
		if (a == null || !OverlayState.enabled) return;
		Intent i = new Intent(a, OverlayService.class);
		try {
			if (Build.VERSION.SDK_INT >= 26) a.startForegroundService(i);
			else a.startService(i);
		} catch (RuntimeException e) {
			// démarrage refusé par le système : l'app reste simplement en pause
		}
	}

	@Override
	public void onMainResume() {
		Activity a = getActivity();
		if (a != null) a.stopService(new Intent(a, OverlayService.class));
	}
}
