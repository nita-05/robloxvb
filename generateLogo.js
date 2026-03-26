const fs = require("fs");
const path = require("path");
const { createCanvas, registerFont } = require("canvas");
const GIFEncoder = require("gifencoder");

const SIZE = 512;
const OUTPUT = path.join(__dirname, "logo_animated.gif");
const TOTAL_FRAMES = 30;
const FRAME_DELAY_MS = 60;
const BG_COLOR = "#0a1022";
const GRADIENT_START = "#7a2cff";
const GRADIENT_END = "#00cfff";
const CARD_RADIUS = 112;
const CARD_SIZE = 350;
const FONT_SIZE = 256;

const FONT_PATH = path.join(__dirname, "fonts", "Poppins-Bold.ttf");
let fontFamily = "sans-serif";
if (fs.existsSync(FONT_PATH)) {
  registerFont(FONT_PATH, { family: "Poppins" });
  fontFamily = "Poppins";
} else {
  // Keep script runnable even when custom font is missing.
  console.warn(
    `Warning: Missing font file: ${FONT_PATH}\nUsing fallback font. Add Poppins-Bold.ttf in /fonts for exact look.`
  );
}

function roundedRect(ctx, x, y, width, height, radius) {
  const r = Math.min(radius, width / 2, height / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + width, y, x + width, y + height, r);
  ctx.arcTo(x + width, y + height, x, y + height, r);
  ctx.arcTo(x, y + height, x, y, r);
  ctx.arcTo(x, y, x + width, y, r);
  ctx.closePath();
}

function easePulse(frame, total) {
  const t = (frame / total) * Math.PI * 2;
  return 0.5 + 0.5 * Math.sin(t);
}

function drawVignette(ctx) {
  const g = ctx.createRadialGradient(
    SIZE * 0.5,
    SIZE * 0.45,
    SIZE * 0.12,
    SIZE * 0.5,
    SIZE * 0.5,
    SIZE * 0.72
  );
  g.addColorStop(0, "rgba(20,28,52,0.0)");
  g.addColorStop(1, "rgba(2,6,18,0.55)");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, SIZE, SIZE);
}

function drawFrame(ctx, frameIndex) {
  const pulse = easePulse(frameIndex, TOTAL_FRAMES);
  const pulseStrong = 0.65 + pulse * 0.35;
  const cx = SIZE / 2;
  const cy = SIZE / 2;
  const cardX = cx - CARD_SIZE / 2;
  const cardY = cy - CARD_SIZE / 2;

  ctx.clearRect(0, 0, SIZE, SIZE);
  ctx.fillStyle = BG_COLOR;
  ctx.fillRect(0, 0, SIZE, SIZE);
  drawVignette(ctx);

  // Outer glow pulse
  ctx.save();
  ctx.shadowColor = `rgba(82, 164, 255, ${0.22 + pulse * 0.28})`;
  ctx.shadowBlur = 45 + pulse * 28;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 8;
  roundedRect(ctx, cardX, cardY, CARD_SIZE, CARD_SIZE, CARD_RADIUS);
  ctx.fillStyle = "rgba(40, 72, 150, 0.16)";
  ctx.fill();
  ctx.restore();

  // Card gradient with slight animated shift
  const shift = Math.sin((frameIndex / TOTAL_FRAMES) * Math.PI * 2) * 28;
  const grad = ctx.createLinearGradient(
    cardX - shift,
    cardY - shift,
    cardX + CARD_SIZE + shift,
    cardY + CARD_SIZE + shift
  );
  grad.addColorStop(0, GRADIENT_START);
  grad.addColorStop(1, GRADIENT_END);

  ctx.save();
  roundedRect(ctx, cardX, cardY, CARD_SIZE, CARD_SIZE, CARD_RADIUS);
  ctx.fillStyle = grad;
  ctx.fill();
  ctx.restore();

  // Glossy top highlight (glass effect)
  ctx.save();
  roundedRect(ctx, cardX, cardY, CARD_SIZE, CARD_SIZE, CARD_RADIUS);
  ctx.clip();
  const gloss = ctx.createLinearGradient(cardX, cardY, cardX, cardY + CARD_SIZE);
  gloss.addColorStop(0, `rgba(255,255,255,${0.32 + pulse * 0.06})`);
  gloss.addColorStop(0.25, "rgba(255,255,255,0.10)");
  gloss.addColorStop(0.55, "rgba(255,255,255,0.02)");
  gloss.addColorStop(1, "rgba(255,255,255,0)");
  ctx.fillStyle = gloss;
  ctx.fillRect(cardX, cardY, CARD_SIZE, CARD_SIZE);
  ctx.restore();

  // Inner shadow for depth
  ctx.save();
  roundedRect(ctx, cardX, cardY, CARD_SIZE, CARD_SIZE, CARD_RADIUS);
  ctx.clip();
  ctx.strokeStyle = "rgba(0,0,0,0.22)";
  ctx.lineWidth = 16;
  ctx.shadowColor = "rgba(0,0,0,0.45)";
  ctx.shadowBlur = 18;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 6;
  roundedRect(
    ctx,
    cardX + 8,
    cardY + 8,
    CARD_SIZE - 16,
    CARD_SIZE - 16,
    CARD_RADIUS - 8
  );
  ctx.stroke();
  ctx.restore();

  // Subtle border
  ctx.save();
  ctx.strokeStyle = "rgba(255,255,255,0.34)";
  ctx.lineWidth = 2;
  roundedRect(ctx, cardX + 1, cardY + 1, CARD_SIZE - 2, CARD_SIZE - 2, CARD_RADIUS - 1);
  ctx.stroke();
  ctx.restore();

  // V text with synchronized glow pulse
  ctx.save();
  ctx.font = `700 ${FONT_SIZE}px "${fontFamily}"`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = "#ffffff";
  ctx.shadowColor = `rgba(255,255,255,${0.28 + pulse * 0.42})`;
  ctx.shadowBlur = 10 + pulse * 16;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 0;
  ctx.fillText("V", cx, cy + 4);
  ctx.restore();

  // Soft edge vignette for depth polish
  ctx.save();
  const edge = ctx.createRadialGradient(cx, cy, SIZE * 0.34, cx, cy, SIZE * 0.66);
  edge.addColorStop(0, "rgba(0,0,0,0)");
  edge.addColorStop(1, "rgba(0,0,0,0.2)");
  ctx.fillStyle = edge;
  ctx.fillRect(0, 0, SIZE, SIZE);
  ctx.restore();
}

function generate() {
  const canvas = createCanvas(SIZE, SIZE);
  const ctx = canvas.getContext("2d");
  ctx.antialias = "subpixel";
  ctx.quality = "best";
  ctx.patternQuality = "best";
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = "high";

  const encoder = new GIFEncoder(SIZE, SIZE);
  const output = fs.createWriteStream(OUTPUT);
  encoder.createReadStream().pipe(output);

  encoder.start();
  encoder.setRepeat(0); // infinite loop
  encoder.setDelay(FRAME_DELAY_MS);
  encoder.setQuality(10);

  for (let i = 0; i < TOTAL_FRAMES; i += 1) {
    drawFrame(ctx, i);
    encoder.addFrame(ctx);
  }

  encoder.finish();

  output.on("finish", () => {
    console.log(`Saved: ${OUTPUT}`);
  });
}

generate();
