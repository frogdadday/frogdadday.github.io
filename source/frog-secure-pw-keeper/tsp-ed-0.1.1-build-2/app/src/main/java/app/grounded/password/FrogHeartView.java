package app.grounded.password;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.view.View;

/** The same local frog-heart mark used for optional support in the other frog apps. */
final class FrogHeartView extends View {
    private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint outline = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint eyes = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint pupils = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path heart = new Path();

    FrogHeartView(Context context) { this(context, null); }
    FrogHeartView(Context context, AttributeSet attrs) {
        super(context, attrs);
        setContentDescription("Optional support: Buy Me a Coffee");
        setFocusable(true);
        outline.setColor(0xB3FFFFFF); outline.setStyle(Paint.Style.STROKE);
        eyes.setColor(0xFFFFFFFF); pupils.setColor(0xFF11131B);
    }
    @Override protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        super.onSizeChanged(w, h, oldw, oldh);
        float width = w, height = h;
        heart.reset();
        if (width <= 0 || height <= 0) return;
        heart.moveTo(width * .50f, height * .96f);
        heart.cubicTo(width * .40f, height * .82f, width * .06f, height * .62f, width * .06f, height * .30f);
        heart.cubicTo(width * .06f, height * .08f, width * .34f, height * .01f, width * .50f, height * .24f);
        heart.cubicTo(width * .66f, height * .01f, width * .94f, height * .08f, width * .94f, height * .30f);
        heart.cubicTo(width * .94f, height * .62f, width * .60f, height * .82f, width * .50f, height * .96f);
        heart.close();
        fill.setShader(new LinearGradient(0, 0, width, height, 0xFFFFDC45, 0xFFFF5CBF, Shader.TileMode.CLAMP));
    }
    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float width = getWidth(), height = getHeight();
        canvas.drawPath(heart, fill);
        outline.setStrokeWidth(width * .05f); canvas.drawPath(heart, outline);
        for (int eye = 0; eye < 2; eye++) {
            float x = width * (eye == 0 ? .30f : .70f);
            canvas.drawCircle(x, height * .25f, width * .105f, eyes);
            canvas.drawCircle(x, height * .25f, width * .047f, pupils);
        }
    }
}
