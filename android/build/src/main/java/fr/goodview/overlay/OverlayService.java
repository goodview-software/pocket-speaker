package fr.goodview.overlay;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.provider.Settings;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Service de premier plan (garde l'app vivante) + bulle flottante (SYSTEM_ALERT_WINDOW). */
public class OverlayService extends Service {
	private static final String CHANNEL = "overlay";
	private static final int NOTIF_ID = 4242;
	private static OverlayService inst;
	private final Handler ui = new Handler();

	private WindowManager wm;
	private WindowManager.LayoutParams lp;
	private LinearLayout bubble;
	private TextView dot, bSound, bMic;
	private String label = "";

	static void refresh() {
		final OverlayService s = inst;
		if (s != null) s.ui.post(s::update);
	}

	@Override
	public IBinder onBind(Intent i) {
		return null;
	}

	@Override
	public void onCreate() {
		super.onCreate();
		inst = this;
		label = getApplicationInfo().loadLabel(getPackageManager()).toString();
	}

	@Override
	public int onStartCommand(Intent intent, int flags, int startId) {
		startForegroundCompat();
		if (Settings.canDrawOverlays(this) && bubble == null) buildBubble();
		update();
		return START_NOT_STICKY;
	}

	@Override
	public void onDestroy() {
		inst = null;
		if (bubble != null) {
			try {
				wm.removeView(bubble);
			} catch (RuntimeException ignored) {
			}
			bubble = null;
		}
		super.onDestroy();
	}

	private Intent launchIntent() {
		Intent i = getPackageManager().getLaunchIntentForPackage(getPackageName());
		if (i != null) i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
		return i;
	}

	private Notification notification() {
		NotificationManager nm = getSystemService(NotificationManager.class);
		if (Build.VERSION.SDK_INT >= 26)
			nm.createNotificationChannel(new NotificationChannel(CHANNEL, label, NotificationManager.IMPORTANCE_LOW));
		PendingIntent pi = PendingIntent.getActivity(this, 0, launchIntent(), PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
		Notification.Builder b = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(this, CHANNEL) : new Notification.Builder(this);
		return b.setContentTitle(label).setContentText(OverlayState.text.isEmpty() ? "Actif en arrière-plan" : OverlayState.text)
				.setSmallIcon(getApplicationInfo().icon).setContentIntent(pi).setOngoing(true).build();
	}

	private void startForegroundCompat() {
		Notification n = notification();
		try {
			startForeground(NOTIF_ID, n);
		} catch (SecurityException e) {
			// ex. micro non accordé : on retombe sur le type lecture audio
			if (Build.VERSION.SDK_INT >= 29)
				startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
			else throw e;
		}
	}

	private int dp(int v) {
		return Math.round(v * getResources().getDisplayMetrics().density);
	}

	private TextView button(String t) {
		TextView b = new TextView(this);
		b.setText(t);
		b.setTextSize(18);
		b.setGravity(Gravity.CENTER);
		b.setTextColor(Color.WHITE);
		LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(dp(40), dp(40));
		p.leftMargin = dp(4);
		b.setLayoutParams(p);
		return b;
	}

	private void buildBubble() {
		wm = (WindowManager) getSystemService(Context.WINDOW_SERVICE);
		bubble = new LinearLayout(this);
		bubble.setOrientation(LinearLayout.HORIZONTAL);
		bubble.setGravity(Gravity.CENTER_VERTICAL);
		bubble.setPadding(dp(4), dp(4), dp(4), dp(4));
		GradientDrawable bg = new GradientDrawable();
		bg.setColor(Color.argb(230, 24, 26, 32));
		bg.setCornerRadius(dp(28));
		bubble.setBackground(bg);

		dot = button(label.isEmpty() ? "P" : label.substring(0, 1));
		dot.setTypeface(Typeface.DEFAULT_BOLD);
		dot.setTextSize(16);
		((LinearLayout.LayoutParams) dot.getLayoutParams()).leftMargin = 0;
		bSound = button("");
		bMic = button("");
		bSound.setOnClickListener(v -> act("sound"));
		bMic.setOnClickListener(v -> act("mic"));
		bubble.addView(dot);
		bubble.addView(bSound);
		bubble.addView(bMic);

		// glisser = déplacer ; toucher = rouvrir l'app
		dot.setOnTouchListener(new View.OnTouchListener() {
			float sx, sy;
			int ox, oy;
			boolean moved;

			@Override
			public boolean onTouch(View v, MotionEvent e) {
				switch (e.getActionMasked()) {
					case MotionEvent.ACTION_DOWN:
						sx = e.getRawX(); sy = e.getRawY(); ox = lp.x; oy = lp.y; moved = false;
						return true;
					case MotionEvent.ACTION_MOVE:
						if (Math.abs(e.getRawX() - sx) > dp(6) || Math.abs(e.getRawY() - sy) > dp(6)) moved = true;
						if (moved) {
							lp.x = ox + Math.round(e.getRawX() - sx);
							lp.y = oy + Math.round(e.getRawY() - sy);
							wm.updateViewLayout(bubble, lp);
						}
						return true;
					case MotionEvent.ACTION_UP:
						if (!moved) {
							Intent i = launchIntent();
							if (i != null) startActivity(i);
						}
						return true;
				}
				return false;
			}
		});

		int type = Build.VERSION.SDK_INT >= 26 ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY : WindowManager.LayoutParams.TYPE_PHONE;
		lp = new WindowManager.LayoutParams(WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
				type, WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, PixelFormat.TRANSLUCENT);
		lp.gravity = Gravity.TOP | Gravity.START;
		lp.x = dp(12);
		lp.y = dp(160);
		try {
			wm.addView(bubble, lp);
		} catch (RuntimeException e) {
			bubble = null;
		}
	}

	private void act(String a) {
		OverlayState.action = a;
		// retour visuel immédiat ; GDScript renverra l'état réel
		if (a.equals("sound")) OverlayState.sound = !OverlayState.sound;
		else OverlayState.mic = !OverlayState.mic;
		update();
	}

	private void update() {
		NotificationManager nm = getSystemService(NotificationManager.class);
		nm.notify(NOTIF_ID, notification());
		if (bubble == null) return;
		GradientDrawable d = new GradientDrawable();
		d.setShape(GradientDrawable.OVAL);
		d.setColor(OverlayState.ok ? Color.rgb(46, 160, 67) : Color.rgb(110, 118, 129));
		dot.setBackground(d);
		int vis = OverlayState.buttons ? View.VISIBLE : View.GONE;
		bSound.setVisibility(vis);
		bMic.setVisibility(vis);
		bSound.setText(OverlayState.sound ? "🔊" : "🔇");
		bMic.setText(OverlayState.mic ? "🎤" : "🚫");
		bSound.setAlpha(OverlayState.sound ? 1f : 0.5f);
		bMic.setAlpha(OverlayState.mic ? 1f : 0.5f);
	}
}
