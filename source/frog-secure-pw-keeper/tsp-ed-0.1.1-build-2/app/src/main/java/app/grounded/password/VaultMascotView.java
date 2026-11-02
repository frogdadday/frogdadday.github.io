package app.grounded.password;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.view.View;

/**
 * Frog Secure PW Keeper's recolored version of Cosmic Spinner's in-app frog.
 * The geometry mirrors YellowFrogPainter rather than either app's launcher icon.
 */
final class VaultMascotView extends View {
    private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path body = new Path();
    private final Path smile = new Path();
    private final RectF ovalBounds = new RectF();

    VaultMascotView(Context context) {
        super(context);
        setContentDescription("Frog Secure PW Keeper frog mascot");
        setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_YES);
        setSaveEnabled(false);
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float width = getWidth();
        float height = getHeight();
        float side = Math.min(width, height);
        float left = (width - side) / 2f;
        canvas.save();
        canvas.translate(left, 0);

        float headTop = height * 0.25f;
        float headBottom = height * 0.80f;
        float eyeSize = side * 0.30f;
        float eyeTop = headTop - eyeSize * 0.20f;

        body.reset();
        body.moveTo(side * 0.10f, headBottom);
        body.quadTo(side * 0.50f, headBottom + height * 0.15f, side * 0.90f, headBottom);
        body.lineTo(side * 0.90f, headTop + height * 0.08f);
        body.quadTo(side * 0.50f, headTop - height * 0.03f, side * 0.10f, headTop + height * 0.08f);
        body.close();
        body.addOval(oval(side * 0.34f, eyeTop + eyeSize / 2f, eyeSize, eyeSize), Path.Direction.CW);
        body.addOval(oval(side * 0.66f, eyeTop + eyeSize / 2f, eyeSize, eyeSize), Path.Direction.CW);

        fill.setStyle(Paint.Style.FILL);
        fill.setColor(Color.WHITE);
        canvas.drawPath(body, fill);
        stroke.setStyle(Paint.Style.STROKE);
        stroke.setStrokeJoin(Paint.Join.ROUND);
        stroke.setStrokeCap(Paint.Cap.ROUND);
        stroke.setStrokeWidth(Math.max(3.2f, side * 0.065f));
        stroke.setColor(Color.BLACK);
        canvas.drawPath(body, stroke);

        float eyeY = height * 0.29f;
        float eyeRadius = side * 0.15f;
        for (int eye = 0; eye < 2; eye++) {
            float eyeX = side * (eye == 0 ? .34f : .66f);
            fill.setColor(Color.rgb(116, 255, 0));
            canvas.drawOval(oval(eyeX, eyeY, eyeRadius * 1.48f, eyeRadius * 1.58f), fill);
            stroke.setStrokeWidth(Math.max(1.4f, side * 0.03f));
            canvas.drawOval(oval(eyeX, eyeY, eyeRadius * 1.48f, eyeRadius * 1.58f), stroke);
            fill.setColor(Color.BLACK);
            canvas.drawOval(oval(eyeX, eyeY + eyeRadius * 0.08f,
                    eyeRadius * 0.70f, eyeRadius * 0.78f), fill);
            fill.setColor(Color.WHITE);
            canvas.drawCircle(eyeX - eyeRadius * 0.12f, eyeY - eyeRadius * 0.10f,
                    Math.max(1f, eyeRadius * 0.10f), fill);
        }

        smile.reset();
        smile.moveTo(side * 0.35f, height * 0.55f);
        smile.quadTo(side * 0.50f, height * 0.67f, side * 0.65f, height * 0.55f);
        stroke.setStrokeWidth(Math.max(2.2f, side * 0.045f));
        canvas.drawPath(smile, stroke);
        canvas.restore();
    }

    private RectF oval(float centerX, float centerY, float width, float height) {
        ovalBounds.set(centerX - width / 2f, centerY - height / 2f,
                centerX + width / 2f, centerY + height / 2f);
        return ovalBounds;
    }
}
