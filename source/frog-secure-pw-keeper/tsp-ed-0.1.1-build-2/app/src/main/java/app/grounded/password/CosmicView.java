package app.grounded.password;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.os.SystemClock;
import android.view.View;
import android.view.ViewGroup;
import java.util.ArrayList;
import java.util.List;

/** Draws the existing views directly: no screenshots, bitmap copies, or vault changes. */
final class CosmicView extends View {
    private record Particle(View view, float x, float y, boolean frog) {}
    private final List<Particle> particles = new ArrayList<>();
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final long started = SystemClock.elapsedRealtime();
    private Runnable completion;
    private final int background;

    CosmicView(Context context, View source, int background, Runnable completion) {
        super(context);
        this.background = background;
        this.completion = completion;
        int[] origin = new int[2]; source.getLocationOnScreen(origin);
        collect(source, origin);
        setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);
    }

    private void collect(View view, int[] origin) {
        if (view.getVisibility() != VISIBLE) return;
        if (view instanceof ViewGroup group) {
            for (int i = 0; i < group.getChildCount(); i++) collect(group.getChildAt(i), origin);
        } else if (view.getGlobalVisibleRect(new Rect())) {
            int[] location = new int[2]; view.getLocationOnScreen(location);
            particles.add(new Particle(view, location[0] - origin[0], location[1] - origin[1],
                    view instanceof VaultMascotView));
        }
    }

    void cancel() { completion = null; particles.clear(); }

    private void drawTwinklePuff(Canvas canvas, float cx, float cy, float progress) {
        float base = Math.min(getWidth(), getHeight()) * (.035f + progress * .10f);
        for (int i = 0; i < 15; i++) {
            double angle = i * Math.PI * 2 / 15 + progress * 3;
            float distance = base * (.35f + (i % 4) * .23f) * progress;
            float x = cx + (float) Math.cos(angle) * distance;
            float y = cy + (float) Math.sin(angle) * distance;
            float size = base * (.10f + (i % 3) * .035f) * (1 - progress * .45f);
            paint.setColor(i % 2 == 0 ? 0xFFFFDC45 : 0xFFFFA7E1);
            paint.setAlpha((int) (255 * (1 - progress)));
            canvas.drawCircle(x, y, size, paint);
            if (i % 3 == 0) {
                paint.setStrokeWidth(Math.max(1, size * .35f));
                canvas.drawLine(x - size * 2, y, x + size * 2, y, paint);
                canvas.drawLine(x, y - size * 2, x, y + size * 2, paint);
            }
        }
        paint.setAlpha(255);
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        long elapsed = SystemClock.elapsedRealtime() - started;
        if (elapsed >= 7000) {
            canvas.drawColor(Color.BLACK);
            if (elapsed >= 9000) {
                Runnable done = completion; completion = null;
                if (done != null) post(done);
            } else postInvalidateOnAnimation();
            return;
        }
        float t = elapsed / 7000f;
        float cx = getWidth() / 2f, cy = getHeight() / 2f;
        float radius = (float) Math.hypot(cx, cy) * t * t;
        canvas.drawColor(background);
        paint.setColor(0xFF763BCE);
        canvas.drawCircle(cx, cy, radius + 10 * (1 - t), paint);
        paint.setColor(Color.BLACK); canvas.drawCircle(cx, cy, radius, paint);
        // The mascot makes more turns, stays larger, then ends in a small twinkle puff.
        for (Particle p : particles) {
            float duration = p.frog ? 6400f : 5400f;
            float progress = Math.min(1f, elapsed / duration);
            if (progress >= 1) continue;
            float shrink = p.frog
                    ? .46f + .54f * (float) Math.pow(1 - progress, .75)
                    : (float) Math.pow(1 - progress, 1.3);
            float dx = p.x + p.view.getWidth() / 2f - cx;
            float dy = p.y + p.view.getHeight() / 2f - cy;
            double angle = progress * progress * Math.PI * (p.frog ? 16 : 13);
            float travel = p.frog ? 1 - progress : shrink;
            float x = cx + (float)(dx * Math.cos(angle) - dy * Math.sin(angle)) * travel;
            float y = cy + (float)(dx * Math.sin(angle) + dy * Math.cos(angle)) * travel;
            canvas.save();
            canvas.translate(x, y);
            canvas.rotate(progress * 540);
            canvas.scale(shrink, shrink);
            canvas.translate(-p.view.getWidth() / 2f, -p.view.getHeight() / 2f);
            p.view.draw(canvas);
            canvas.restore();
        }
        if (elapsed >= 6400) drawTwinklePuff(canvas, cx, cy, (elapsed - 6400) / 600f);
        postInvalidateOnAnimation();
    }
}
