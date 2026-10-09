import processing.sound.*;

// =========================================================================
// CHECKERS vs AI
// You play RED (moves upward), the computer plays BLACK (moves downward).
// Diagonal moves, multi-jumps, kings. Captures are OPTIONAL (not forced) -
// you can always choose a plain step instead of an available jump.
// AI: minimax search with alpha-beta pruning. AI pauses 2 seconds before
// moving, the same on every difficulty. Difficulty buttons (Easy/Medium/
// Hard/Insane) control search depth; Easy also has a chance to play a
// deliberately weaker move. On top of that, every difficulty has a 1-in-25
// chance per move of deliberately playing into its worst available spot,
// so even Hard/Insane occasionally blunder. Pieces slide smoothly to their destination,
// hop by hop on multi-jumps, instead of jumping there instantly.
// =========================================================================

final int EMPTY = 0, RED = 1, RED_KING = 2, BLACK = 3, BLACK_KING = 4;
final int SIZE = 8;
final int CELL = 70;
final int OFFX = 30, OFFY = 110;
final int AI_DELAY_MS = 2000; // flat artificial "thinking" pause, same on every difficulty

// Difficulty = search depth, plus a chance of a deliberately weaker move on Easy.
final int[] DEPTHS       = {2, 6, 8, 10};
final float[] RANDOMNESS = {0.45f, 0f, 0f, 0f}; // chance Easy ignores the best move
final float BLUNDER_CHANCE = 1.0f / 25.0f; // on every difficulty, a 1-in-25 chance the AI deliberately plays its worst move
final String[] DIFF_NAMES = {"Easy", "Medium", "Hard", "Insane"};
int difficulty = 1; // 0=Easy, 1=Medium (default), 2=Hard, 3=Insane

// ---- slide animation state ----
final int ANIM_STEP_MS = 220; // duration of a single hop (a multi-jump animates hop by hop)
boolean animating = false;
Move animMove = null;
boolean animIsRedMove = false;
int animIndex = 0;
int animStepStart = 0;
int animPieceType = 0;

int[][] board = new int[SIZE][SIZE];
boolean redTurn = true;      // human (red) moves first
boolean gameOver = false;
String statusMsg = "";
boolean aiPending = false;
int aiPendingStart = -1;

int selR = -1, selC = -1;
ArrayList<Move> selectedMoves = new ArrayList<Move>();

// ---- menu music ----
SoundFile menuMusic;
boolean musicOn = false;
boolean musicMenuOpen = false;
ArrayList<String> musicPaths = new ArrayList<String>();
ArrayList<String> musicNames = new ArrayList<String>();
int currentMusicIndex = -1;
String pendingMusicPath = null;

final float MUSIC_BTN_X = 30, MUSIC_BTN_Y_OFFSET = 51, MUSIC_BTN_SIZE = 44;
float musicBtnY() { return height - MUSIC_BTN_Y_OFFSET; }

// ---- filler buttons: timer / volume / mute / debug ----
final float FILLER_Y = 706;
final float VOL_READOUT_Y = 674; // just below the board, above the knob
float fillerBtnX(int i) { return 35 + i * 140; }

boolean timerOn = false;
int timerStartMillis = 0;
boolean debugOn = false;

// ---- volume knob (0-100, drag vertically to adjust) ----
float knobValue = 80;
boolean knobDragging = false;
float knobDragStartY = 0;
float knobDragStartValue = 0;
final float KNOB_R = 15;
float knobCX() { return fillerBtnX(1) + 65; }
float knobCY() { return FILLER_Y + 15; }

class Move {
  ArrayList<int[]> path = new ArrayList<int[]>();
  ArrayList<int[]> captured = new ArrayList<int[]>();
}

// =========================================================================
void setup() {
  size(620, 820);
  surface.setTitle("Checkers vs AI");
  initBoard();

  try {
    File f = new File(dataPath("menu_music.mp3"));
    if (f.exists()) {
      musicPaths.add(f.getAbsolutePath());
      musicNames.add("Popular-feat: Playboy Carti, Madonna, and the Weekend");
    }
  } catch (Exception e) {
    println("No menu music found.");
  }
}

void initBoard() {
  for (int r = 0; r < SIZE; r++)
    for (int c = 0; c < SIZE; c++)
      board[r][c] = EMPTY;

  for (int r = 0; r < SIZE; r++) {
    for (int c = 0; c < SIZE; c++) {
      if ((r + c) % 2 == 1) {
        if (r < 3) board[r][c] = BLACK;
        else if (r > 4) board[r][c] = RED;
      }
    }
  }
  redTurn = true;
  gameOver = false;
  aiPending = false;
  selR = -1; selC = -1;
  selectedMoves.clear();
  statusMsg = "Your move (red)";
}

// =========================================================================
void draw() {
  if (chessMode) updateCAnimation(); else updateAnimation();

  if (pendingMusicPath != null) {
    String p = pendingMusicPath;
    pendingMusicPath = null;
    addMusicTrack(p);
  }

  background(40);
  drawBoard();
  if (chessMode) {
    drawCPieces();
    drawCAnimPiece();
    drawCHighlights();
  } else {
    drawPieces();
    drawAnimPiece();
    drawHighlights();
  }
  drawUI();

  if (chessMode) {
    if (!cAnimating && cAiPending && millis() - cAiPendingStart >= AI_DELAY_MS) {
      cAiPending = false;
      performCAIMove();
    }
  } else {
    if (!animating && aiPending && millis() - aiPendingStart >= AI_DELAY_MS) {
      aiPending = false;
      performAIMove();
    }
  }
}

void drawBoard() {
  for (int r = 0; r < SIZE; r++) {
    for (int c = 0; c < SIZE; c++) {
      fill((r + c) % 2 == 0 ? color(235, 220, 195) : color(90, 60, 40));
      noStroke();
      rect(OFFX + c * CELL, OFFY + r * CELL, CELL, CELL);
    }
  }
}

void drawPieces() {
  for (int r = 0; r < SIZE; r++) {
    for (int c = 0; c < SIZE; c++) {
      int p = board[r][c];
      if (p == EMPTY) continue;
      if (isHiddenDuringAnim(r, c)) continue;
      float cx = OFFX + c * CELL + CELL / 2.0f;
      float cy = OFFY + r * CELL + CELL / 2.0f;
      float d = CELL * 0.72f;

      noStroke();
      fill(0, 90);
      ellipse(cx + 3, cy + 4, d, d);

      fill(isRed(p) ? color(200, 40, 40) : color(30, 30, 30));
      stroke(255, 230);
      strokeWeight(2);
      ellipse(cx, cy, d, d);

      if (isKing(p)) {
        fill(255, 210, 60);
        textAlign(CENTER, CENTER);
        textSize(20);
        noStroke();
        text("K", cx, cy);
      }
    }
  }
}

void drawHighlights() {
  if (selR != -1) {
    noFill();
    stroke(80, 220, 255);
    strokeWeight(3);
    rect(OFFX + selC * CELL, OFFY + selR * CELL, CELL, CELL);

    noStroke();
    fill(80, 220, 255, 150);
    for (Move m : selectedMoves) {
      int[] to = m.path.get(m.path.size() - 1);
      ellipse(OFFX + to[1] * CELL + CELL / 2.0f, OFFY + to[0] * CELL + CELL / 2.0f, 18, 18);
    }
  }
}

void drawUI() {
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(20);
  text(chessMode ? cStatusMsg : statusMsg, width / 2, 22);

  drawDifficultyButtons();

  boolean newGameHov = hit(width / 2 - 70, height - 46, 140, 34);
  boolean newGamePressed = newGameHov && mousePressed;
  float newGameLabelY = drawPixelButton(width / 2 - 70, height - 46, 140, 34, newGamePressed, newGameHov, PBTN_GREEN);
  fill(30);
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(14);
  text("New Game", width / 2, newGameLabelY);

  boolean switchHov = hit(width - 170, height - 46, 150, 34);
  boolean switchPressed = switchHov && mousePressed;
  float switchLabelY = drawPixelButton(width - 170, height - 46, 150, 34, switchPressed, switchHov, PBTN_BLUE);
  fill(25);
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(13);
  text(chessMode ? "Switch to Checkers" : "Switch to Chess", width - 95, switchLabelY);

  drawMusicButton();
  drawFillerButtons();
  drawTimerAndDebug();
  if (musicMenuOpen) drawMusicMenu();
}

void drawFillerButtons() {
  boolean tHov = hit(fillerBtnX(0), FILLER_Y, 130, 30);
  float tLabelY = drawPixelButton(fillerBtnX(0), FILLER_Y, 130, 30, timerOn, tHov, PBTN_ORANGE);
  fill(30);
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(12);
  text("Timer", fillerBtnX(0) + 65, tLabelY);

  drawVolumeReadout();
  drawVolumeKnob();

  boolean dHov = hit(fillerBtnX(2), FILLER_Y, 130, 30);
  float dLabelY = drawPixelButton(fillerBtnX(2), FILLER_Y, 130, 30, debugOn, dHov, PBTN_ORANGE);
  fill(30);
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(12);
  text("Debug", fillerBtnX(2) + 65, dLabelY);
}

// a round rotary-style knob; drag vertically to set 0-100 (sidesteps angle
// wraparound issues a true click-and-rotate control would have)
void drawVolumeKnob() {
  float cx = knobCX(), cy = knobCY(), r = KNOB_R;
  boolean hov = dist(mouseX, mouseY, cx, cy) <= r;

  color baseC  = (hov || knobDragging) ? lerpColor(PBTN_ORANGE, color(255), 0.2f) : PBTN_ORANGE;
  color ring1  = lerpColor(PBTN_ORANGE, PBTN_SHADE, 0.35f);
  color ring2  = lerpColor(PBTN_ORANGE, PBTN_SHADE, 0.7f);

  noStroke();
  fill(ring2);
  ellipse(cx, cy, r * 2 + 8, r * 2 + 8);
  fill(ring1);
  ellipse(cx, cy, r * 2 + 4, r * 2 + 4);
  fill(baseC);
  ellipse(cx, cy, r * 2, r * 2);
  noFill();
  stroke(PBTN_OUTLINE);
  strokeWeight(1.5f);
  ellipse(cx, cy, r * 2, r * 2);

  // indicator sweeps 280 degrees, leaving a gap at the bottom like a real knob
  float ang = map(knobValue, 0, 100, radians(-140), radians(140));
  stroke(30);
  strokeWeight(2);
  line(cx, cy, cx + cos(ang) * r * 0.75f, cy + sin(ang) * r * 0.75f);

}

// small LCD-style readout box showing the current volume, sitting right above the knob
void drawVolumeReadout() {
  float w = 90, h = 24;
  float x = knobCX() - w / 2;
  float y = VOL_READOUT_Y;

  fill(25, 25, 32);
  stroke(PBTN_OUTLINE);
  strokeWeight(1.5f);
  rect(x, y, w, h, 6);

  fill(PBTN_YELLOW);
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(13);
  text("Vol: " + round(knobValue), x + w / 2, y + h / 2);
}

void drawTimerAndDebug() {
  if (timerOn) {
    int secs = (millis() - timerStartMillis) / 1000;
    fill(255);
    noStroke();
    textAlign(LEFT, CENTER);
    textSize(13);
    text(nf(secs / 60, 2) + ":" + nf(secs % 60, 2), 10, 10);
  }
  if (debugOn) {
    fill(255);
    noStroke();
    textAlign(RIGHT, CENTER);
    textSize(13);
    text(round(frameRate) + " fps", width - 10, 10);
  }
}

// =========================================================================
// PIXEL-ART BUTTON (chunky, layered, raised when idle / sunken when "pressed")
// =========================================================================
color PBTN_GREEN   = color(176, 219, 110);
color PBTN_ORANGE  = color(232, 151, 58);
color PBTN_BLUE    = color(91, 155, 213);
color PBTN_YELLOW  = color(240, 221, 123); // top highlight strip - stays the same warm tone on every color
color PBTN_SHADE   = color(20, 20, 30);    // everything darkens toward this for the side/base bands
color PBTN_OUTLINE = color(18, 18, 24);

void topChamferRect(float x, float y, float w, float h, float c, color col) {
  fill(col);
  noStroke();
  beginShape();
  vertex(x + c, y); vertex(x + w - c, y); vertex(x + w, y + c);
  vertex(x + w, y + h); vertex(x, y + h); vertex(x, y + c);
  endShape(CLOSE);
}

void bottomChamferRect(float x, float y, float w, float h, float c, color col) {
  fill(col);
  noStroke();
  beginShape();
  vertex(x, y); vertex(x + w, y); vertex(x + w, y + h - c);
  vertex(x + w - c, y + h); vertex(x + c, y + h); vertex(x, y + h - c);
  endShape(CLOSE);
}

void chamferOutline(float x, float y, float w, float h, float c) {
  noFill();
  stroke(PBTN_OUTLINE);
  strokeWeight(2);
  beginShape();
  vertex(x + c, y); vertex(x + w - c, y); vertex(x + w, y + c); vertex(x + w, y + h - c);
  vertex(x + w - c, y + h); vertex(x + c, y + h); vertex(x, y + h - c); vertex(x, y + c);
  endShape(CLOSE);
}

// Draws a chunky layered button. pressed=true sinks it down to its base (like the
// reference image's "clicked" state); pressed=false shows it fully raised.
// Returns the y-coordinate to vertically center a text label on the top face.
float drawPixelButton(float x, float y, float w, float h, boolean pressed, boolean hover, color base) {
  float baseY = y + h;
  float totalH = pressed ? h * 0.55f : h;
  float topY = baseY - totalH;
  float chamfer = min(min(w, totalH) * 0.16f, 8);

  color topColor  = (hover && !pressed) ? lerpColor(base, color(255), 0.22f) : base;
  color side1     = lerpColor(base, PBTN_SHADE, 0.35f);
  color side2     = lerpColor(base, PBTN_SHADE, 0.55f);
  color baseShade = lerpColor(base, PBTN_SHADE, 0.80f);

  if (!pressed) {
    float faceH = totalH * 0.42f;
    float s1H   = totalH * 0.16f;
    float s2H   = totalH * 0.16f;
    float navyH = totalH - faceH - s1H - s2H;

    topChamferRect(x, topY, w, faceH, chamfer, topColor);
    fill(PBTN_YELLOW);
    noStroke();
    rect(x + chamfer * 0.7f, topY + chamfer * 0.6f, w - chamfer * 1.4f, faceH * 0.22f);
    fill(side1);
    rect(x, topY + faceH, w, s1H);
    fill(side2);
    rect(x, topY + faceH + s1H, w, s2H);
    bottomChamferRect(x, topY + faceH + s1H + s2H, w, navyH, chamfer, baseShade);

    stroke(PBTN_OUTLINE);
    strokeWeight(1.2f);
    line(x, topY + faceH, x + w, topY + faceH);
    line(x, topY + faceH + s1H, x + w, topY + faceH + s1H);
    line(x, topY + faceH + s1H + s2H, x + w, topY + faceH + s1H + s2H);

    chamferOutline(x, topY, w, totalH, chamfer);
    return topY + faceH / 2;
  } else {
    float faceH = totalH * 0.38f;
    float navyH = totalH - faceH;

    topChamferRect(x, topY, w, faceH, chamfer, topColor);
    fill(PBTN_YELLOW);
    noStroke();
    rect(x + chamfer * 0.7f, topY + chamfer * 0.6f, w - chamfer * 1.4f, faceH * 0.22f);
    bottomChamferRect(x, topY + faceH, w, navyH, chamfer, baseShade);

    stroke(PBTN_OUTLINE);
    strokeWeight(1.2f);
    line(x, topY + faceH, x + w, topY + faceH);

    chamferOutline(x, topY, w, totalH, chamfer);
    return topY + faceH / 2;
  }
}

// square icon button, bottom-left: raised idle/hover, sinks down while the menu is open
void drawMusicButton() {
  boolean hov = hit(MUSIC_BTN_X, musicBtnY(), MUSIC_BTN_SIZE, MUSIC_BTN_SIZE);
  float labelY = drawPixelButton(MUSIC_BTN_X, musicBtnY(), MUSIC_BTN_SIZE, MUSIC_BTN_SIZE, musicMenuOpen, hov, PBTN_GREEN);
  fill(35);
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(16);
  text("M", MUSIC_BTN_X + MUSIC_BTN_SIZE / 2, labelY);
}

// ---------- music menu panel ----------
float mpX = 140, mpY = 140, mpW = 340, mpH = 400;
float mpRowH = 36;
float mpAddBtnH = 38;

void drawMusicMenu() {
  fill(15, 15, 15, 235);
  stroke(70, 200, 220);
  strokeWeight(2);
  rect(mpX, mpY, mpW, mpH, 12);

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(20);
  text("Music", mpX + mpW / 2, mpY + 26);

  int maxRows = 7;
  for (int i = 0; i < musicNames.size() && i < maxRows; i++) {
    float ry = mpY + 50 + i * mpRowH;
    float rw = mpW - 24;
    float rh = mpRowH - 6;
    boolean hov = hit(mpX + 12, ry, rw, rh);
    boolean playing = (i == currentMusicIndex && musicOn);
    float labelY = drawPixelButton(mpX + 12, ry, rw, rh, playing, hov, PBTN_GREEN);
    fill(30);
    noStroke();
    textAlign(LEFT, CENTER);
    textSize(12);
    text(shorten(musicNames.get(i), 30), mpX + 24, labelY);
  }
  if (musicNames.size() > maxRows) {
    fill(160);
    textAlign(CENTER, CENTER);
    textSize(12);
    text("+" + (musicNames.size() - maxRows) + " more", mpX + mpW / 2, mpY + 50 + maxRows * mpRowH + 8);
  }
  if (musicNames.isEmpty()) {
    fill(160);
    textAlign(CENTER, CENTER);
    textSize(13);
    text("No songs yet - add one below", mpX + mpW / 2, mpY + 90);
  }

  float addY = mpY + mpH - mpAddBtnH - 14;
  float addW = mpW - 40;
  boolean addHov = hit(mpX + 20, addY, addW, mpAddBtnH);
  boolean addPressed = addHov && mousePressed;
  float addLabelY = drawPixelButton(mpX + 20, addY, addW, mpAddBtnH, addPressed, addHov, PBTN_GREEN);
  fill(30);
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(14);
  text("+ Add MP3 File", mpX + mpW / 2, addLabelY);
}

String shorten(String s, int n) {
  return s.length() > n ? s.substring(0, n - 3) + "..." : s;
}

float diffBtnX(int i) { return 35 + i * 140; }

void drawDifficultyButtons() {
  for (int i = 0; i < 4; i++) {
    boolean active = (i == difficulty);
    boolean hov = hit(diffBtnX(i), 48, 130, 28);
    float labelY = drawPixelButton(diffBtnX(i), 48, 130, 28, active, hov, PBTN_ORANGE);
    fill(30);
    noStroke();
    textAlign(CENTER, CENTER);
    textSize(13);
    text(DIFF_NAMES[i], diffBtnX(i) + 65, labelY);
  }
}

// =========================================================================
// SLIDE ANIMATION
// =========================================================================
void startAnimation(Move m, boolean wasRedMove) {
  animMove = m;
  animIsRedMove = wasRedMove;
  animIndex = 0;
  animStepStart = millis();
  int[] src = m.path.get(0);
  animPieceType = board[src[0]][src[1]]; // board not mutated yet - safe to read here
  animating = true;
}

void updateAnimation() {
  if (!animating) return;
  float t = (millis() - animStepStart) / (float) ANIM_STEP_MS;
  if (t >= 1) {
    animIndex++;
    if (animIndex >= animMove.path.size() - 1) {
      finishAnimatedMove();
    } else {
      animStepStart = millis();
    }
  }
}

void drawAnimPiece() {
  if (!animating) return;
  int[] from = animMove.path.get(animIndex);
  int[] to = animMove.path.get(animIndex + 1);
  float t = constrain((millis() - animStepStart) / (float) ANIM_STEP_MS, 0, 1);
  float te = t * t * (3 - 2 * t); // smoothstep easing

  float cx = lerp(OFFX + from[1] * CELL + CELL / 2.0f, OFFX + to[1] * CELL + CELL / 2.0f, te);
  float cy = lerp(OFFY + from[0] * CELL + CELL / 2.0f, OFFY + to[0] * CELL + CELL / 2.0f, te);
  float d = CELL * 0.72f;

  noStroke();
  fill(0, 90);
  ellipse(cx + 3, cy + 4, d, d);

  fill(isRed(animPieceType) ? color(200, 40, 40) : color(30, 30, 30));
  stroke(255, 230);
  strokeWeight(2);
  ellipse(cx, cy, d, d);

  if (isKing(animPieceType)) {
    fill(255, 210, 60);
    textAlign(CENTER, CENTER);
    textSize(20);
    noStroke();
    text("K", cx, cy);
  }
}

// while mid-slide, hide the square the piece departed from, plus any
// enemy pieces already jumped over so far in a multi-jump
boolean isHiddenDuringAnim(int r, int c) {
  if (!animating) return false;
  int[] src = animMove.path.get(0);
  if (r == src[0] && c == src[1]) return true;
  for (int i = 0; i <= animIndex && i < animMove.captured.size(); i++) {
    int[] cap = animMove.captured.get(i);
    if (r == cap[0] && c == cap[1]) return true;
  }
  return false;
}

// called once the slide reaches its final square: commits the move to the
// real board and runs the same post-move logic the old instant-move code did
void finishAnimatedMove() {
  board = applyMove(board, animMove);
  boolean wasRed = animIsRedMove;
  animating = false;
  animMove = null;

  if (wasRed) {
    ArrayList<Move> blackMoves = getAllMoves(board, false);
    if (blackMoves.isEmpty()) {
      gameOver = true;
      statusMsg = "You win! AI has no moves left.";
    } else {
      redTurn = false;
      aiPending = true;
      aiPendingStart = millis();
      statusMsg = "AI is thinking...";
    }
  } else {
    redTurn = true;
    ArrayList<Move> redMoves = getAllMoves(board, true);
    if (redMoves.isEmpty()) {
      gameOver = true;
      statusMsg = "AI wins! You have no moves left.";
    } else {
      statusMsg = "Your move (red)";
    }
  }
}

// =========================================================================
// PIECE HELPERS
// =========================================================================
boolean isRed(int p)   { return p == RED || p == RED_KING; }
boolean isBlack(int p) { return p == BLACK || p == BLACK_KING; }
boolean isKing(int p)  { return p == RED_KING || p == BLACK_KING; }
boolean inBounds(int r, int c) { return r >= 0 && r < SIZE && c >= 0 && c < SIZE; }

int[][] jumpDirs(int piece) {
  if (piece == RED_KING || piece == BLACK_KING)
    return new int[][]{{-1,-1},{-1,1},{1,-1},{1,1}};
  if (piece == RED)
    return new int[][]{{-1,-1},{-1,1}};
  return new int[][]{{1,-1},{1,1}}; // BLACK man
}

int[][] copyBoard(int[][] b) {
  int[][] nb = new int[SIZE][SIZE];
  for (int r = 0; r < SIZE; r++) nb[r] = b[r].clone();
  return nb;
}

// =========================================================================
// MOVE GENERATION
// =========================================================================
// Captures are optional now: this returns every legal move (jumps AND plain
// steps) for the side, rather than forcing a jump whenever one is available.
ArrayList<Move> getAllMoves(int[][] b, boolean redSide) {
  ArrayList<Move> moves = new ArrayList<Move>();

  for (int r = 0; r < SIZE; r++) {
    for (int c = 0; c < SIZE; c++) {
      int p = b[r][c];
      if (p == EMPTY) continue;
      if (redSide && !isRed(p)) continue;
      if (!redSide && !isBlack(p)) continue;
      ArrayList<int[]> path = new ArrayList<int[]>();
      path.add(new int[]{r, c});
      findCaptures(b, r, c, path, new ArrayList<int[]>(), moves, redSide);
    }
  }

  for (int r = 0; r < SIZE; r++) {
    for (int c = 0; c < SIZE; c++) {
      int p = b[r][c];
      if (p == EMPTY) continue;
      if (redSide && !isRed(p)) continue;
      if (!redSide && !isBlack(p)) continue;
      for (int[] d : jumpDirs(p)) {
        int lr = r + d[0], lc = c + d[1];
        if (inBounds(lr, lc) && b[lr][lc] == EMPTY) {
          Move m = new Move();
          m.path.add(new int[]{r, c});
          m.path.add(new int[]{lr, lc});
          moves.add(m);
        }
      }
    }
  }
  return moves;
}

// recursively extends a jump sequence; records a Move each time a branch runs out of further jumps
void findCaptures(int[][] b, int r, int c, ArrayList<int[]> path, ArrayList<int[]> captured, ArrayList<Move> results, boolean redSide) {
  int piece = b[r][c];
  boolean found = false;

  for (int[] d : jumpDirs(piece)) {
    int mr = r + d[0], mc = c + d[1];
    int lr = r + d[0] * 2, lc = c + d[1] * 2;
    if (!inBounds(lr, lc) || !inBounds(mr, mc)) continue;
    if (b[lr][lc] != EMPTY) continue;
    int mid = b[mr][mc];
    if (mid == EMPTY) continue;
    if (redSide && isRed(mid)) continue;
    if (!redSide && isBlack(mid)) continue;

    int[][] nb = copyBoard(b);
    nb[r][c] = EMPTY;
    nb[mr][mc] = EMPTY;
    int newPiece = piece;
    if (piece == RED && lr == 0) newPiece = RED_KING;
    if (piece == BLACK && lr == SIZE - 1) newPiece = BLACK_KING;
    nb[lr][lc] = newPiece;

    ArrayList<int[]> newPath = new ArrayList<int[]>(path);
    newPath.add(new int[]{lr, lc});
    ArrayList<int[]> newCaptured = new ArrayList<int[]>(captured);
    newCaptured.add(new int[]{mr, mc});

    found = true;
    findCaptures(nb, lr, lc, newPath, newCaptured, results, redSide);
  }

  if (!found && captured.size() > 0) {
    Move m = new Move();
    m.path = path;
    m.captured = captured;
    results.add(m);
  }
}

int[][] applyMove(int[][] b, Move m) {
  int[][] nb = copyBoard(b);
  int[] from = m.path.get(0);
  int[] to = m.path.get(m.path.size() - 1);
  int piece = nb[from[0]][from[1]];
  nb[from[0]][from[1]] = EMPTY;
  for (int[] cap : m.captured) nb[cap[0]][cap[1]] = EMPTY;
  if (piece == RED && to[0] == 0) piece = RED_KING;
  if (piece == BLACK && to[0] == SIZE - 1) piece = BLACK_KING;
  nb[to[0]][to[1]] = piece;
  return nb;
}

// =========================================================================
// AI: minimax with alpha-beta pruning (maximizes for BLACK)
// =========================================================================
float evaluate(int[][] b) {
  float score = 0;
  for (int r = 0; r < SIZE; r++) {
    for (int c = 0; c < SIZE; c++) {
      int p = b[r][c];
      if (p == RED)        score -= 1.0f + 0.02f * (SIZE - 1 - r);
      else if (p == RED_KING)   score -= 1.6f;
      else if (p == BLACK)      score += 1.0f + 0.02f * r;
      else if (p == BLACK_KING) score += 1.6f;
    }
  }
  return score;
}

float minimax(int[][] b, int depth, float alpha, float beta, boolean blackToMove) {
  ArrayList<Move> moves = getAllMoves(b, !blackToMove);
  if (moves.isEmpty()) return blackToMove ? -1000 : 1000; // side to move has no moves = they lose
  if (depth == 0) return evaluate(b);

  if (blackToMove) {
    float best = -Float.MAX_VALUE;
    for (Move m : moves) {
      float score = minimax(applyMove(b, m), depth - 1, alpha, beta, false);
      best = max(best, score);
      alpha = max(alpha, best);
      if (beta <= alpha) break;
    }
    return best;
  } else {
    float best = Float.MAX_VALUE;
    for (Move m : moves) {
      float score = minimax(applyMove(b, m), depth - 1, alpha, beta, true);
      best = min(best, score);
      beta = min(beta, best);
      if (beta <= alpha) break;
    }
    return best;
  }
}

void performAIMove() {
  ArrayList<Move> moves = getAllMoves(board, false);
  if (moves.isEmpty()) {
    gameOver = true;
    statusMsg = "You win! AI has no moves left.";
    return;
  }

  int depth = DEPTHS[difficulty];
  float bestScore = -Float.MAX_VALUE;
  float worstScore = Float.MAX_VALUE;
  Move bestMove = moves.get(0);
  Move worstMove = moves.get(0);
  for (Move m : moves) {
    float score = minimax(applyMove(board, m), depth - 1, -Float.MAX_VALUE, Float.MAX_VALUE, false);
    if (score > bestScore) {
      bestScore = score;
      bestMove = m;
    }
    if (score < worstScore) {
      worstScore = score;
      worstMove = m;
    }
  }

  Move chosenMove = bestMove;

  // Easy occasionally throws away the best move in favor of a random legal one
  if (random(1) < RANDOMNESS[difficulty]) {
    chosenMove = moves.get(int(random(moves.size())));
  }
  // every difficulty has a small chance of deliberately walking into its
  // worst available spot, so the AI isn't flawless even on Hard/Insane
  else if (random(1) < BLUNDER_CHANCE) {
    chosenMove = worstMove;
  }

  startAnimation(chosenMove, false);
}

// =========================================================================
// INTERACTION
// =========================================================================
void mousePressed() {
  if (hit(MUSIC_BTN_X, musicBtnY(), MUSIC_BTN_SIZE, MUSIC_BTN_SIZE)) {
    musicMenuOpen = !musicMenuOpen;
    return;
  }

  if (dist(mouseX, mouseY, knobCX(), knobCY()) <= KNOB_R) {
    knobDragging = true;
    knobDragStartY = mouseY;
    knobDragStartValue = knobValue;
    return;
  }
  if (hit(fillerBtnX(0), FILLER_Y, 130, 30)) {
    timerOn = !timerOn;
    if (timerOn) timerStartMillis = millis();
    return;
  }
  if (hit(fillerBtnX(2), FILLER_Y, 130, 30)) {
    debugOn = !debugOn;
    return;
  }

  if (musicMenuOpen) {
    handleMusicMenuClick();
    return;
  }

  for (int i = 0; i < 4; i++) {
    if (hit(diffBtnX(i), 48, 130, 28)) {
      difficulty = i;
      return;
    }
  }

  if (hit(width - 170, height - 46, 150, 34)) {
    toggleMode();
    return;
  }

  if (chessMode) {
    if (cAnimating) return;
    if (hit(width / 2 - 70, height - 46, 140, 34)) {
      initChessBoard();
      return;
    }
    if (cGameOver || !whiteTurn || cAiPending) return;

    int ccol = (mouseX - OFFX) / CELL;
    int crow = (mouseY - OFFY) / CELL;
    if (!inBounds(crow, ccol)) return;
    handleChessClick(crow, ccol);
    return;
  }

  if (animating) return;

  if (hit(width / 2 - 70, height - 46, 140, 34)) {
    initBoard();
    return;
  }
  if (gameOver || !redTurn || aiPending) return;

  int col = (mouseX - OFFX) / CELL;
  int row = (mouseY - OFFY) / CELL;
  if (!inBounds(row, col)) return;

  if (selR == -1) {
    ArrayList<Move> allRed = getAllMoves(board, true);
    ArrayList<Move> forThis = new ArrayList<Move>();
    for (Move m : allRed) {
      int[] from = m.path.get(0);
      if (from[0] == row && from[1] == col) forThis.add(m);
    }
    if (!forThis.isEmpty()) {
      selR = row; selC = col;
      selectedMoves = forThis;
    }
  } else {
    if (row == selR && col == selC) {
      selR = -1; selectedMoves.clear();
      return;
    }
    Move chosen = null;
    for (Move m : selectedMoves) {
      int[] to = m.path.get(m.path.size() - 1);
      if (to[0] == row && to[1] == col) { chosen = m; break; }
    }
    if (chosen != null) {
      selR = -1; selectedMoves.clear();
      startAnimation(chosen, true);
    } else if (isRed(board[row][col])) {
      // clicked a different one of your pieces - try reselecting
      ArrayList<Move> allRed = getAllMoves(board, true);
      ArrayList<Move> forThis = new ArrayList<Move>();
      for (Move m : allRed) {
        int[] from = m.path.get(0);
        if (from[0] == row && from[1] == col) forThis.add(m);
      }
      if (!forThis.isEmpty()) {
        selR = row; selC = col;
        selectedMoves = forThis;
      }
    }
  }
}

boolean hit(float x, float y, float w, float h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

void mouseDragged() {
  if (knobDragging) {
    float dy = knobDragStartY - mouseY; // dragging up increases the value
    knobValue = constrain(knobDragStartValue + dy * 0.6f, 0, 100);
    applyKnobVolume();
  }
}

void mouseReleased() {
  knobDragging = false;
}

void applyKnobVolume() {
  if (menuMusic == null) return;
  try { menuMusic.amp(knobValue / 100.0f); } catch (Exception e) {}
}

void handleMusicMenuClick() {
  int maxRows = 7;
  for (int i = 0; i < musicNames.size() && i < maxRows; i++) {
    float ry = mpY + 50 + i * mpRowH;
    if (hit(mpX + 12, ry, mpW - 24, mpRowH - 6)) {
      if (i == currentMusicIndex && musicOn) stopMusic();
      else playMusicTrack(i);
      return;
    }
  }

  float addY = mpY + mpH - mpAddBtnH - 14;
  if (hit(mpX + 20, addY, mpW - 40, mpAddBtnH)) {
    selectInput("Choose an MP3 to add", "musicFileSelected");
    return;
  }

  if (!hit(mpX, mpY, mpW, mpH)) {
    musicMenuOpen = false; // clicked outside the panel
  }
  // click landed inside the panel but not on a control - absorb it, do nothing
}

// called by selectInput() on the file-dialog thread: just remember the path,
// draw() loads it on the main thread
void musicFileSelected(File selection) {
  if (selection == null) return;
  pendingMusicPath = selection.getAbsolutePath();
}

void addMusicTrack(String path) {
  String name = new File(path).getName();
  if (!name.toLowerCase().endsWith(".mp3")) return;
  musicPaths.add(path);
  musicNames.add(name);
}

void playMusicTrack(int index) {
  try {
    if (menuMusic != null) menuMusic.stop();
    menuMusic = new SoundFile(this, musicPaths.get(index));
    menuMusic.amp(knobValue / 100.0f);
    menuMusic.loop();
    currentMusicIndex = index;
    musicOn = true;
  } catch (Exception e) {
    println("Could not play that file.");
  }
}

void stopMusic() {
  if (menuMusic != null) {
    try { menuMusic.stop(); } catch (Exception e) {}
  }
  musicOn = false;
  currentMusicIndex = -1;
}

// =========================================================================
// CHESS MODE
// =========================================================================
final int PAWN = 1, KNIGHT = 2, BISHOP = 3, ROOK = 4, QUEEN = 5, KING = 6;
final int[] CHESS_DEPTHS = {1, 2, 3, 4}; // shallower than checkers - chess has a much bigger branching factor

boolean chessMode = false;

int[][] cboard = new int[SIZE][SIZE];
boolean whiteTurn = true;
boolean cGameOver = false;
String cStatusMsg = "";
boolean cAiPending = false;
int cAiPendingStart = -1;

boolean wKingMoved = false, bKingMoved = false;
boolean wRookAMoved = false, wRookHMoved = false, bRookAMoved = false, bRookHMoved = false;
int epTargetR = -1, epTargetC = -1, epPawnR = -1, epPawnC = -1;

int cSelR = -1, cSelC = -1;
ArrayList<CMove> cSelMoves = new ArrayList<CMove>();

boolean cAnimating = false;
CMove cAnimMove = null;
boolean cAnimWasWhite = false;
int cAnimStepStart = 0;
int cAnimPieceType = 0;
final int CANIM_MS = 260;

class CMove {
  int fr, fc, tr, tc;
  boolean castleK = false, castleQ = false, enPassant = false;
  int epCapR = -1, epCapC = -1; // pawn removed by an en passant capture
}

void initChessBoard() {
  for (int r = 0; r < SIZE; r++) for (int c = 0; c < SIZE; c++) cboard[r][c] = 0;
  int[] order = {ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK};
  for (int c = 0; c < 8; c++) {
    cboard[0][c] = -order[c];
    cboard[1][c] = -PAWN;
    cboard[6][c] = PAWN;
    cboard[7][c] = order[c];
  }
  whiteTurn = true;
  cGameOver = false;
  cAiPending = false;
  cAnimating = false;
  cSelR = -1; cSelC = -1; cSelMoves.clear();
  wKingMoved = false; bKingMoved = false;
  wRookAMoved = false; wRookHMoved = false; bRookAMoved = false; bRookHMoved = false;
  epTargetR = -1; epTargetC = -1; epPawnR = -1; epPawnC = -1;
  cStatusMsg = "Your move (white)";
}

void toggleMode() {
  chessMode = !chessMode;
  if (chessMode) {
    initChessBoard();
    surface.setTitle("Chess vs AI");
  } else {
    initBoard();
    surface.setTitle("Checkers vs AI");
  }
}

// ---------- piece helpers ----------
boolean cWhite(int p) { return p > 0; }
int cType(int p) { return abs(p); }

CMove cm(int fr, int fc, int tr, int tc) {
  CMove m = new CMove();
  m.fr = fr; m.fc = fc; m.tr = tr; m.tc = tc;
  return m;
}

// pseudo-legal moves for one piece: normal moves/captures only, no castling/en passant
ArrayList<CMove> genBasicMoves(int[][] b, int r, int c) {
  ArrayList<CMove> out = new ArrayList<CMove>();
  int p = b[r][c];
  if (p == 0) return out;
  boolean white = cWhite(p);
  int type = cType(p);

  if (type == PAWN) {
    int dir = white ? -1 : 1;
    int startRow = white ? 6 : 1;
    if (inBounds(r + dir, c) && b[r + dir][c] == 0) {
      out.add(cm(r, c, r + dir, c));
      if (r == startRow && b[r + 2 * dir][c] == 0) out.add(cm(r, c, r + 2 * dir, c));
    }
    for (int dc = -1; dc <= 1; dc += 2) {
      int nr = r + dir, nc = c + dc;
      if (inBounds(nr, nc) && b[nr][nc] != 0 && cWhite(b[nr][nc]) != white) out.add(cm(r, c, nr, nc));
    }
  } else if (type == KNIGHT) {
    int[][] offs = {{-2,-1},{-2,1},{-1,-2},{-1,2},{1,-2},{1,2},{2,-1},{2,1}};
    for (int[] o : offs) {
      int nr = r + o[0], nc = c + o[1];
      if (inBounds(nr, nc) && (b[nr][nc] == 0 || cWhite(b[nr][nc]) != white)) out.add(cm(r, c, nr, nc));
    }
  } else if (type == KING) {
    for (int dr = -1; dr <= 1; dr++) for (int dc = -1; dc <= 1; dc++) {
      if (dr == 0 && dc == 0) continue;
      int nr = r + dr, nc = c + dc;
      if (inBounds(nr, nc) && (b[nr][nc] == 0 || cWhite(b[nr][nc]) != white)) out.add(cm(r, c, nr, nc));
    }
  } else { // bishop, rook, queen - sliding
    int[][] dirs;
    if (type == BISHOP) dirs = new int[][]{{-1,-1},{-1,1},{1,-1},{1,1}};
    else if (type == ROOK) dirs = new int[][]{{-1,0},{1,0},{0,-1},{0,1}};
    else dirs = new int[][]{{-1,-1},{-1,1},{1,-1},{1,1},{-1,0},{1,0},{0,-1},{0,1}};
    for (int[] d : dirs) {
      int nr = r + d[0], nc = c + d[1];
      while (inBounds(nr, nc)) {
        if (b[nr][nc] == 0) {
          out.add(cm(r, c, nr, nc));
        } else {
          if (cWhite(b[nr][nc]) != white) out.add(cm(r, c, nr, nc));
          break;
        }
        nr += d[0]; nc += d[1];
      }
    }
  }
  return out;
}

// every pseudo-legal move for a side, ignoring castling/en passant - used deep in the AI search
ArrayList<CMove> genSimpleMoves(int[][] b, boolean white) {
  ArrayList<CMove> out = new ArrayList<CMove>();
  for (int r = 0; r < SIZE; r++) for (int c = 0; c < SIZE; c++) {
    int p = b[r][c];
    if (p == 0 || cWhite(p) != white) continue;
    out.addAll(genBasicMoves(b, r, c));
  }
  return out;
}

boolean isSquareAttacked(int[][] b, int r, int c, boolean byWhite) {
  for (int r2 = 0; r2 < SIZE; r2++) for (int c2 = 0; c2 < SIZE; c2++) {
    int p = b[r2][c2];
    if (p == 0 || cWhite(p) != byWhite) continue;
    int type = cType(p);
    if (type == PAWN) {
      int dir = byWhite ? -1 : 1;
      if (r2 + dir == r && abs(c2 - c) == 1) return true;
    } else {
      for (CMove m : genBasicMoves(b, r2, c2)) if (m.tr == r && m.tc == c) return true;
    }
  }
  return false;
}

int[] findKing(int[][] b, boolean white) {
  for (int r = 0; r < SIZE; r++) for (int c = 0; c < SIZE; c++)
    if (b[r][c] == (white ? KING : -KING)) return new int[]{r, c};
  return new int[]{-1, -1};
}

// root-level legal moves: normal moves + castling + en passant, with king-safety filtering
ArrayList<CMove> getLegalChessMoves(boolean white) {
  ArrayList<CMove> raw = new ArrayList<CMove>();
  for (int r = 0; r < SIZE; r++) for (int c = 0; c < SIZE; c++) {
    int p = cboard[r][c];
    if (p == 0 || cWhite(p) != white) continue;
    raw.addAll(genBasicMoves(cboard, r, c));
  }

  // en passant
  if (epTargetR != -1) {
    int row = white ? 3 : 4;
    if (epPawnR == row) {
      for (int dc = -1; dc <= 1; dc += 2) {
        int c = epPawnC + dc;
        if (inBounds(row, c) && cboard[row][c] == (white ? PAWN : -PAWN)) {
          CMove m = cm(row, c, epTargetR, epTargetC);
          m.enPassant = true; m.epCapR = epPawnR; m.epCapC = epPawnC;
          raw.add(m);
        }
      }
    }
  }

  // castling
  int homeRow = white ? 7 : 0;
  boolean kingMoved = white ? wKingMoved : bKingMoved;
  boolean rookAMoved = white ? wRookAMoved : bRookAMoved;
  boolean rookHMoved = white ? wRookHMoved : bRookHMoved;
  if (!kingMoved && cboard[homeRow][4] == (white ? KING : -KING) && !isSquareAttacked(cboard, homeRow, 4, !white)) {
    if (!rookHMoved && cboard[homeRow][7] == (white ? ROOK : -ROOK) && cboard[homeRow][5] == 0 && cboard[homeRow][6] == 0
        && !isSquareAttacked(cboard, homeRow, 5, !white) && !isSquareAttacked(cboard, homeRow, 6, !white)) {
      CMove m = cm(homeRow, 4, homeRow, 6); m.castleK = true; raw.add(m);
    }
    if (!rookAMoved && cboard[homeRow][0] == (white ? ROOK : -ROOK) && cboard[homeRow][1] == 0 && cboard[homeRow][2] == 0 && cboard[homeRow][3] == 0
        && !isSquareAttacked(cboard, homeRow, 3, !white) && !isSquareAttacked(cboard, homeRow, 2, !white)) {
      CMove m = cm(homeRow, 4, homeRow, 2); m.castleQ = true; raw.add(m);
    }
  }

  // filter out moves that leave your own king in check
  ArrayList<CMove> legal = new ArrayList<CMove>();
  for (CMove m : raw) {
    int[][] sim = copyBoard(cboard);
    simApplyCMove(sim, m);
    int[] k = findKing(sim, white);
    if (!isSquareAttacked(sim, k[0], k[1], !white)) legal.add(m);
  }
  return legal;
}

// applies a move to an arbitrary board copy (used for legality checks and the AI's search)
void simApplyCMove(int[][] b, CMove m) {
  int piece = b[m.fr][m.fc];
  b[m.fr][m.fc] = 0;
  if (m.enPassant) b[m.epCapR][m.epCapC] = 0;
  if (m.castleK) { b[m.fr][5] = b[m.fr][7]; b[m.fr][7] = 0; }
  if (m.castleQ) { b[m.fr][3] = b[m.fr][0]; b[m.fr][0] = 0; }
  if (cType(piece) == PAWN && (m.tr == 0 || m.tr == 7)) piece = cWhite(piece) ? QUEEN : -QUEEN;
  b[m.tr][m.tc] = piece;
}

// commits a move to the real game state: board + castling rights + en passant tracking
void applyCMoveReal(CMove m) {
  int piece = cboard[m.fr][m.fc];
  boolean wasDoublePawn = cType(piece) == PAWN && abs(m.tr - m.fr) == 2;

  simApplyCMove(cboard, m);

  if (cType(piece) == KING) { if (cWhite(piece)) wKingMoved = true; else bKingMoved = true; }
  if (cType(piece) == ROOK) {
    if (m.fr == 7 && m.fc == 0) wRookAMoved = true;
    if (m.fr == 7 && m.fc == 7) wRookHMoved = true;
    if (m.fr == 0 && m.fc == 0) bRookAMoved = true;
    if (m.fr == 0 && m.fc == 7) bRookHMoved = true;
  }

  if (wasDoublePawn) {
    epTargetR = (m.fr + m.tr) / 2;
    epTargetC = m.fc;
    epPawnR = m.tr;
    epPawnC = m.fc;
  } else {
    epTargetR = -1; epTargetC = -1; epPawnR = -1; epPawnC = -1;
  }
}

// =========================================================================
// CHESS AI
// =========================================================================
float cEvaluate(int[][] b) {
  float score = 0;
  for (int r = 0; r < SIZE; r++) for (int c = 0; c < SIZE; c++) {
    int p = b[r][c];
    if (p == 0) continue;
    int t = cType(p);
    float v;
    if (t == PAWN) v = 1;
    else if (t == KNIGHT) v = 3;
    else if (t == BISHOP) v = 3.1f;
    else if (t == ROOK) v = 5;
    else if (t == QUEEN) v = 9;
    else v = 1000; // KING
    score += cWhite(p) ? -v : v;
  }
  return score;
}

float cMinimax(int[][] b, int depth, float alpha, float beta, boolean whiteToMove) {
  if (depth == 0) return cEvaluate(b);
  ArrayList<CMove> moves = genSimpleMoves(b, whiteToMove);
  if (moves.isEmpty()) return cEvaluate(b);

  if (!whiteToMove) { // black (AI) maximizes
    float best = -Float.MAX_VALUE;
    for (CMove m : moves) {
      int[][] nb = copyBoard(b);
      simApplyCMove(nb, m);
      float score = cMinimax(nb, depth - 1, alpha, beta, true);
      best = max(best, score);
      alpha = max(alpha, best);
      if (beta <= alpha) break;
    }
    return best;
  } else {
    float best = Float.MAX_VALUE;
    for (CMove m : moves) {
      int[][] nb = copyBoard(b);
      simApplyCMove(nb, m);
      float score = cMinimax(nb, depth - 1, alpha, beta, false);
      best = min(best, score);
      beta = min(beta, best);
      if (beta <= alpha) break;
    }
    return best;
  }
}

void performCAIMove() {
  ArrayList<CMove> moves = getLegalChessMoves(false);
  if (moves.isEmpty()) {
    cGameOver = true;
    int[] k = findKing(cboard, false);
    cStatusMsg = isSquareAttacked(cboard, k[0], k[1], true) ? "Checkmate! You win." : "Stalemate - it's a draw.";
    return;
  }

  int depth = CHESS_DEPTHS[difficulty];
  float bestScore = -Float.MAX_VALUE, worstScore = Float.MAX_VALUE;
  CMove bestMove = moves.get(0), worstMove = moves.get(0);
  for (CMove m : moves) {
    int[][] nb = copyBoard(cboard);
    simApplyCMove(nb, m);
    float score = cMinimax(nb, depth - 1, -Float.MAX_VALUE, Float.MAX_VALUE, true);
    if (score > bestScore) { bestScore = score; bestMove = m; }
    if (score < worstScore) { worstScore = score; worstMove = m; }
  }

  CMove chosen = bestMove;
  if (random(1) < RANDOMNESS[difficulty]) chosen = moves.get(int(random(moves.size())));
  else if (random(1) < BLUNDER_CHANCE) chosen = worstMove;

  startCAnimation(chosen, false);
}

// =========================================================================
// CHESS ANIMATION
// =========================================================================
void startCAnimation(CMove m, boolean wasWhite) {
  cAnimMove = m;
  cAnimWasWhite = wasWhite;
  cAnimStepStart = millis();
  cAnimPieceType = cboard[m.fr][m.fc];
  cAnimating = true;
}

void updateCAnimation() {
  if (!cAnimating) return;
  if (millis() - cAnimStepStart >= CANIM_MS) finishCAnimatedMove();
}

void finishCAnimatedMove() {
  applyCMoveReal(cAnimMove);
  boolean wasWhite = cAnimWasWhite;
  cAnimating = false;
  cAnimMove = null;

  boolean nextWhite = !wasWhite;
  ArrayList<CMove> nextMoves = getLegalChessMoves(nextWhite);
  int[] k = findKing(cboard, nextWhite);
  boolean inCheck = isSquareAttacked(cboard, k[0], k[1], !nextWhite);

  if (nextMoves.isEmpty()) {
    cGameOver = true;
    if (inCheck) cStatusMsg = nextWhite ? "Checkmate! AI wins." : "Checkmate! You win.";
    else cStatusMsg = "Stalemate - it's a draw.";
    return;
  }

  whiteTurn = nextWhite;
  if (nextWhite) {
    cStatusMsg = inCheck ? "Check! Your move (white)" : "Your move (white)";
  } else {
    cStatusMsg = inCheck ? "Check! AI is thinking..." : "AI is thinking...";
    cAiPending = true;
    cAiPendingStart = millis();
  }
}

void drawCAnimPiece() {
  if (!cAnimating) return;
  float t = constrain((millis() - cAnimStepStart) / (float) CANIM_MS, 0, 1);
  float te = t * t * (3 - 2 * t);
  float cx = lerp(OFFX + cAnimMove.fc * CELL + CELL / 2.0f, OFFX + cAnimMove.tc * CELL + CELL / 2.0f, te);
  float cy = lerp(OFFY + cAnimMove.fr * CELL + CELL / 2.0f, OFFY + cAnimMove.tr * CELL + CELL / 2.0f, te);
  drawChessGlyph(cx, cy, cAnimPieceType);
}

// =========================================================================
// CHESS RENDERING
// =========================================================================
void drawCPieces() {
  for (int r = 0; r < SIZE; r++) for (int c = 0; c < SIZE; c++) {
    int p = cboard[r][c];
    if (p == 0) continue;
    if (cAnimating && r == cAnimMove.fr && c == cAnimMove.fc) continue; // lifted, drawn separately
    float cx = OFFX + c * CELL + CELL / 2.0f;
    float cy = OFFY + r * CELL + CELL / 2.0f;
    drawChessGlyph(cx, cy, p);
  }
}

void drawChessGlyph(float cx, float cy, int p) {
  String[] letters = {"", "P", "N", "B", "R", "Q", "K"};
  noStroke();
  fill(0, 90);
  ellipse(cx + 3, cy + 4, CELL * 0.68f, CELL * 0.68f);
  fill(cWhite(p) ? color(240) : color(35));
  stroke(cWhite(p) ? color(90) : color(210));
  strokeWeight(2);
  ellipse(cx, cy, CELL * 0.68f, CELL * 0.68f);
  fill(cWhite(p) ? color(20) : color(235));
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(22);
  text(letters[cType(p)], cx, cy);
}

void drawCHighlights() {
  if (cSelR != -1) {
    noFill();
    stroke(80, 220, 255);
    strokeWeight(3);
    rect(OFFX + cSelC * CELL, OFFY + cSelR * CELL, CELL, CELL);

    noStroke();
    fill(80, 220, 255, 150);
    for (CMove m : cSelMoves) ellipse(OFFX + m.tc * CELL + CELL / 2.0f, OFFY + m.tr * CELL + CELL / 2.0f, 18, 18);
  }
}

// =========================================================================
// CHESS INTERACTION
// =========================================================================
void handleChessClick(int row, int col) {
  if (cSelR == -1) {
    ArrayList<CMove> all = getLegalChessMoves(true);
    ArrayList<CMove> forThis = new ArrayList<CMove>();
    for (CMove m : all) if (m.fr == row && m.fc == col) forThis.add(m);
    if (!forThis.isEmpty()) { cSelR = row; cSelC = col; cSelMoves = forThis; }
  } else {
    if (row == cSelR && col == cSelC) { cSelR = -1; cSelMoves.clear(); return; }
    CMove chosen = null;
    for (CMove m : cSelMoves) if (m.tr == row && m.tc == col) { chosen = m; break; }
    if (chosen != null) {
      cSelR = -1; cSelMoves.clear();
      startCAnimation(chosen, true);
    } else if (cboard[row][col] > 0) {
      ArrayList<CMove> all = getLegalChessMoves(true);
      ArrayList<CMove> forThis = new ArrayList<CMove>();
      for (CMove m : all) if (m.fr == row && m.fc == col) forThis.add(m);
      if (!forThis.isEmpty()) { cSelR = row; cSelC = col; cSelMoves = forThis; }
    }
  }
}
