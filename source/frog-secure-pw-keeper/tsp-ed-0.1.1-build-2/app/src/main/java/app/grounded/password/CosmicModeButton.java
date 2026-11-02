package app.grounded.password;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.view.Gravity;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Compact, local control for the purely visual Cosmic Mode. */
final class CosmicModeButton extends LinearLayout {
    CosmicModeButton(Context context) {
        super(context);
        setOrientation(VERTICAL);
        setGravity(Gravity.CENTER);
        setContentDescription("Cosmic Mode");
        setClickable(true);
        setFocusable(true);
        setFocusableInTouchMode(true);
        addView(new BlackHoleMark(context), new LinearLayout.LayoutParams(dp(36), dp(36)));
        TextView label = new TextView(context);
        label.setText("Cosmic Mode");
        label.setTextSize(10);
        label.setTextColor(Color.rgb(26, 67, 51));
        label.setGravity(Gravity.CENTER);
        label.setPadding(dp(2), dp(2), dp(2), dp(2));
        addView(label, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT));
    }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }

    private static final class BlackHoleMark extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        BlackHoleMark(Context context) { super(context); setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO); }
        @Override protected void onDraw(Canvas canvas) {
            float cx = getWidth() / 2f, cy = getHeight() / 2f, r = Math.min(cx, cy);
            paint.setColor(0xFF813BD6); canvas.drawCircle(cx, cy, r, paint);
            paint.setColor(0xFFC36CFF); paint.setStyle(Paint.Style.STROKE); paint.setStrokeWidth(r * .16f);
            canvas.drawCircle(cx, cy, r * .73f, paint);
            paint.setStyle(Paint.Style.FILL); paint.setColor(Color.BLACK); canvas.drawCircle(cx, cy, r * .56f, paint);
            paint.setColor(0xFFE4C7FF); canvas.drawCircle(cx + r * .27f, cy - r * .31f, r * .10f, paint);
        }
    }
}
